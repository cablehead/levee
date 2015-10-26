
## errors

Consistent error handling

### functions

* get(errno_code):
	returns `err` where `err` is a siphon error for the given errno code

* get_eai(eai_code):
	returns `err` where `err` is a siphon error for the given eai code

* add(code, domain, name, msg):
	registers a new error with the siphon registery

### objects

#### Error

##### methods

* next():
	returns the next error

* is(domain, name):
	returns whether this is error matches the corresponding `domain`, `name`

##### attributes

* is_`domain`\_`name`:
	convenience attribute to call `:is(domain, name)`
