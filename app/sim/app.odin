package sim

import "../data"

app_new_model :: proc(a: ^data.App, $T: typeid) -> data.Model(T) {
	m := data.Model(T){ app = a }
	ptr := new(T)
	if len(a.models_freelist) > 0 {
		m.idx = pop(&a.models_freelist)
		m.gen = a.models_gen[m.idx]
		a.models_ptr[m.idx] = ptr
		return m
	}

	m.idx = u32(len(a.models_ptr))
	m.gen = 1
	append(&a.models_gen, m.gen)
	append(&a.models_ptr, ptr)
	append(&a.observer_roots, nil)
	return m
}

app_delete_model :: proc(a: ^data.App, m: data.Model($T)) {
	if int(m.idx) >= len(a.models_ptr) || m.gen != a.models_gen[m.idx] {
		return
	}

	sub := a.observer_roots[m.idx]
	for sub != nil {
		model_unsubscribe(m, sub, false)
		sub = sub.next
	}

	free(a.models_ptr[m.idx])
	a.models_ptr[m.idx] = {}
	a.models_gen[m.idx] += 1
	a.observer_roots[m.idx] = nil
	append(&a.models_freelist, m.idx)
}
