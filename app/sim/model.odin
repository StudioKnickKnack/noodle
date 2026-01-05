package sim

import "../data"

model_new :: proc(a: ^data.App, $T: typeid) -> data.Model(T) {
	mdl := data.Model(T){ app = a }
	ptr := new(T)
	if len(a.models_freelist) > 0 {
		mdl.idx = pop(&a.models_freelist)
		mdl.gen = a.models_gen[mdl.idx]
		a.models_ptr[mdl.idx] = ptr
		return mdl
	}

	mdl.idx = u32(len(a.models_ptr))
	mdl.gen = 1
	append(&a.models_gen, mdl.gen)
	append(&a.models_ptr, ptr)
	append(&a.observer_roots, nil)
	return mdl
}

model_delete :: proc(mdl: data.Model($T)) {
	if int(mdl.idx) >= len(mdl.app.models_ptr) || mdl.gen != mdl.app.models_gen[mdl.idx] {
		return
	}

	sub := mdl.app.observer_roots[mdl.idx]
	for sub != nil {
		model_unsubscribe(mdl, sub, false)
		sub = sub.next
	}

	free(mdl.app.models_ptr[mdl.idx])
	mdl.app.models_ptr[mdl.idx] = {}
	mdl.app.models_gen[mdl.idx] += 1
	mdl.app.observer_roots[mdl.idx] = nil
	append(&mdl.app.models_freelist, mdl.idx)
}

model_update :: proc(mdl: data.Model($T), cb: proc(^T, data.Model(T))) {
	if int(mdl.idx) >= len(mdl.app.models_ptr) || mdl.gen != mdl.app.models_gen[mdl.idx] {
		return
	}

	ptr := (^T)(mdl.app.models_ptr[mdl.idx])
	cb(ptr, mdl)
}

model_get :: proc(mdl: data.Model($T), cb: proc(T)) {
	if int(mdl.idx) >= len(mdl.app.models_ptr) || mdl.gen != mdl.app.models_gen[mdl.idx] {
		return
	}

	ptr := (^T)(mdl.app.models_ptr[mdl.idx])
	cb(ptr^)
}

model_observe :: proc {
	model_observe_model,
	model_observe_anon,
}

model_observe_model :: proc(observer: data.Model($TObserver), observed: data.Model($TObserved), cb: proc(^TObserver, data.Model(TObserver), TObserved)) -> ^data.Subscription {
	if int(observer.idx) >= len(observer.app.models_ptr) || observer.gen != observer.app.models_gen[observer.idx] {
		return nil
	}
	if int(observed.idx) >= len(observed.app.models_ptr) || observed.gen != observed.app.models_gen[observed.idx] {
		return nil
	}

	ctx := new(data.Subscription_Context(TObserver, TObserved))
	ctx.app = observer.app
	ctx.observer_idx = observer.idx
	ctx.observer_gen = observer.gen
	ctx.observed_idx = observed.idx
	ctx.observed_gen = observed.gen
	ctx.handler = data.Subscription_Handler_Model(TObserver, TObserved) { cb = cb }

	root := observed.app.observer_roots[observed.idx]
	sub := new(data.Subscription)
	sub.ctx = rawptr(ctx)
	if root == nil {
		observed.app.observer_roots[observed.idx] = sub
	} else {
		sub.prev = root
		root.next = sub
	}
	sub.invoke = proc(ctx_ptr: rawptr) {
		ctx := cast(^data.Subscription_Context(TObserver, TObserved))ctx_ptr
		if int(ctx.observed_idx) >= len(ctx.app.models_ptr) || ctx.observed_gen != ctx.app.models_gen[ctx.observed_idx] {
			log.errorf("dangling subscription on observed %v:%v", ctx.observed_idx, ctx.observed_gen)
			return
		}
		observed_ptr := cast(^TObserved)(ctx.app.models_ptr[ctx.observed_idx])
		if int(ctx.observer_idx) >= len(ctx.app.models_ptr) || ctx.observer_gen != ctx.app.models_gen[ctx.observer_idx] {
			log.errorf("dangling subscription with observer %v:%v", ctx.observer_idx, ctx.observer_gen)
			return
		}
		observer_ptr := cast(^TObserver)ctx.app.models_ptr[ctx.observer_idx]
		observer_mdl := data.Model(TObserver) { idx = ctx.observer_idx, gen = ctx.observer_gen, app = ctx.app }
		#partial switch h in ctx.handler {
		case data.Subscription_Handler_Model(TObserver, TObserved):
			h.cb(observer_ptr, observer_mdl, observed_ptr^)
		}
	}
	sub.cleanup = proc(ctx_ptr: rawptr) {
		ctx := cast(^data.Subscription_Context(TObserver, TObserved))ctx_ptr
		free(ctx)
	}

	return sub
}

model_observe_anon :: proc(observed: data.Model($TObserved), cb: proc(TObserved)) -> ^data.Subscription {
	if int(observed.idx) >= len(observed.app.models_ptr) || observed.gen != observed.app.models_gen[observed.idx] {
		return nil
	}

	ctx := new(data.Subscription_Context(TObserved, TObserved))
	ctx.app = observed.app
	ctx.observed_idx = observed.idx
	ctx.observed_gen = observed.gen
	ctx.handler = data.Subscription_Handler_Anonymous(TObserved) { cb = cb }

	root := observed.app.observer_roots[observed.idx]
	sub := new(data.Subscription)
	sub.ctx = rawptr(ctx)
	if root == nil {
		observed.app.observer_roots[observed.idx] = sub
	} else {
		sub.prev = root
		root.next = sub
	}
	sub.invoke = proc(ctx_ptr: rawptr) {
		ctx := cast(^data.Subscription_Context(TObserved, TObserved))ctx_ptr
		if int(ctx.observed_idx) >= len(ctx.app.models_ptr) || ctx.observed_gen != ctx.app.models_gen[ctx.observed_idx] {
			log.errorf("dangling subscription on observed %v:%v", ctx.observed_idx, ctx.observed_gen)
			return
		}
		observed_ptr := cast(^TObserved)ctx.app.models_ptr[ctx.observed_idx]
		#partial switch h in ctx.handler {
		case data.Subscription_Handler_Anonymous(TObserved):
			h.cb(observed_ptr^)
		}
	}
	sub.cleanup = proc(ctx_ptr: rawptr) {
		ctx := cast(^data.Subscription_Context(TObserved, TObserved))ctx_ptr
		free(ctx)
	}

	return sub
}

model_unsubscribe :: proc(mdl: data.Model($T), sub: ^data.Subscription, unlink: bool = true) {
	sub.cleanup(sub.ctx)
	if unlink {
		if sub.prev != nil {
			sub.prev.next = sub.next
		} else {
			mdl.app.observer_roots[mdl.idx] = sub.next
		}
		if sub.next != nil {
			sub.next.prev = sub.prev
		}
	}
	free(sub)
}

model_notify :: proc(mdl: data.Model($T)) {
	if int(mdl.idx) >= len(mdl.app.models_ptr) || mdl.gen != mdl.app.models_gen[mdl.idx] {
		return
	}

	current := mdl.app.observer_roots[mdl.idx]
	for current != nil {
		next := current.next
		current.invoke(current.ctx)
		current = next
	}
}
