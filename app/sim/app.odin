package sim

import "../data"

app_new_model :: proc(a: ^data.App, $T: typeid) -> data.Model(T) {
	m := data.Model(T){}
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
	return m
}

app_delete_model :: proc(a: ^data.App, m: data.Model($T)) {
	if int(m.idx) >= len(a.models_ptr) || m.gen != a.models_gen[m.idx] {
		return
	}

	free(a.models_ptr[m.idx])
	a.models_ptr[m.idx] = {}
	a.models_gen[m.idx] += 1
	append(&a.models_freelist, m.idx)
}
