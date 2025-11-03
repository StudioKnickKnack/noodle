package property

// TODO When this works lets redo it by keeping data plain and having observability external to that (rather than Property)
//      Zed editor does this app context and using model handles to observe/notify on the entire model rather than prop-by-prop.
//      It's probably granular enough but if needed we can always add a state mask that means something to that model and its observers

Subscription :: struct {
	idx: u32,
	gen: u32,
}

SubscriberList :: struct($T: typeid) {
	callbacks: [dynamic]proc(value: T),
	gen:       [dynamic]u32,
	freelist:  [dynamic]Subscription,
	num:       int,
	next_gen:  u32,
}

Property :: struct($T: typeid) {
	value:     T,
	observers: SubscriberList(T),
}

make :: proc($T: typeid, initial: T) -> Property(T) {
	return Property(T){value = initial, observers = SubscriberList(T){next_gen = 1}}
}

delete :: proc(p: ^Property($T)) {
	sl_delete(p.observers)
}

set :: proc(p: ^Property($T), value: T) {
	if p.value == value {
		return
	}

	p.value = value
	it := sl_make_iter(p.observers)
	for o in sl_iter(&it) {
		o(p.value)
	}
}

subscribe :: proc(p: ^Property($T), o: proc(value: T)) -> Subscription {
	return sl_add(&p.observers, o)
}

unsubscribe :: proc(p: ^Property($T), s: Subscription) {
	sl_remove(&p.observers, s)
}

sl_delete :: proc(sl: ^SubscriberList($T)) {
	delete(callbacks)
	delete(freelist)
}

sl_add :: proc(sl: ^SubscriberList($T), o: proc(value: T)) -> Subscription {
	if len(sl.freelist) > 0 {
		s := pop(&sl.freelist)
		s.gen = sl.next_gen
		sl.next_gen += 1
		sl.callbacks[s.idx] = o
		sl.gen[s.idx] = s.gen
		sl.num += 1
		return s
	}

	idx := u32(len(sl.callbacks))
	s := Subscription {
		idx = idx,
		gen = sl.next_gen,
	}
	sl.next_gen += 1
	append(&sl.callbacks, o)
	append(&sl.gen, s.gen)
	sl.num += 1
	return s
}

sl_remove :: proc(sl: ^SubscriberList($T), s: Subscription) {
	sl.gen[s.idx] = 0
	append(&sl.freelist, s)
}

sl_get :: proc(sl: SubscriberList($T), s: Subscription) -> (proc(value: T), bool) {
	if s.gen == 0 {
		return {}, false
	}

	if int(s.idx) < len(sl.callbacks) && sl.gen[s.idx] == s.gen {
		return sl.callbacks[s.idx], true
	}

	return {}, false
}

Subscription_Iter :: struct($T: typeid) {
	sl:  SubscriberList(T),
	idx: int,
}

sl_make_iter :: proc(sl: SubscriberList($T)) -> Subscription_Iter(T) {
	return Subscription_Iter(T){sl = sl}
}

sl_iter :: proc(it: ^Subscription_Iter($T)) -> (s: proc(value: T), valid: bool) {
	in_range := it.idx < len(it.sl.callbacks)
	for in_range {
		valid = in_range && it.sl.gen[it.idx] > 0
		if valid {
			s = it.sl.callbacks[it.idx]
			it.idx += 1
			return
		}

		it.idx += 1
		in_range = it.idx < len(it.sl.callbacks)
	}

	return
}

