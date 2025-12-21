package data

Subscription :: struct {
	prev: ^Subscription,
	next: ^Subscription,
	ctx: rawptr,
	invoke: proc(rawptr),
	cleanup: proc(rawptr),
}

Subscription_Handler :: union($TObserver: typeid, $TObserved: typeid) {
	Subscription_Handler_Model(TObserver, TObserved),
	Subscription_Handler_Anonymous(TObserved),
}

Subscription_Handler_Model :: struct($TObserver: typeid, $TObserved: typeid) {
	cb: proc(^TObserver, Model(TObserver), TObserved),
}

Subscription_Handler_Anonymous :: struct($TObserved: typeid) {
	cb: proc(TObserved),
}

Subscription_Context :: struct($TObserver: typeid, $TObserved: typeid) {
	app: ^App,
	observer_idx: u32,
	observer_gen: u32,
	observed_idx: u32,
	observed_gen: u32,
	//handler: proc(^TObserver, TObserved),
	handler: Subscription_Handler(TObserver, TObserved),
}
