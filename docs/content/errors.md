
## errors

Consistent error handling

### functions

* get(errno_code):
	returns `err` where `err` is a siphon error for the given errno code

* get_eai(eai_code):
	returns `err` where `err` is a siphon error for the given eai code

* add(code, domain, name, msg):
	registers a new error with the siphon registery

