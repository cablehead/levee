local os = require("os")
local io = require("io")

local ffi = require("ffi")
local C = ffi.load("tls")


ffi.cdef([[
static const int TLS_API = 20141031;

static const int TLS_PROTOCOL_TLSv1_0 = (1 << 1);
static const int TLS_PROTOCOL_TLSv1_1 = (1 << 2);
static const int TLS_PROTOCOL_TLSv1_2 = (1 << 3);
static const int TLS_PROTOCOL_TLSv1 =
	(TLS_PROTOCOL_TLSv1_0|TLS_PROTOCOL_TLSv1_1|TLS_PROTOCOL_TLSv1_2);

static const int TLS_PROTOCOLS_ALL = TLS_PROTOCOL_TLSv1;
static const int TLS_PROTOCOLS_DEFAULT = TLS_PROTOCOL_TLSv1_2;

static const int TLS_WANT_POLLIN  = -2;
static const int TLS_WANT_POLLOUT = -3;

struct tls;
struct tls_config;

int tls_init(void);

const char *tls_config_error(struct tls_config *_config);
const char *tls_error(struct tls *_ctx);

struct tls_config *tls_config_new(void);
void tls_config_free(struct tls_config *_config);

int tls_config_set_ca_file(struct tls_config *_config, const char *_ca_file);
int tls_config_set_ca_path(struct tls_config *_config, const char *_ca_path);
int tls_config_set_ca_mem(struct tls_config *_config, const uint8_t *_ca,
    size_t _len);
int tls_config_set_cert_file(struct tls_config *_config,
    const char *_cert_file);
int tls_config_set_cert_mem(struct tls_config *_config, const uint8_t *_cert,
    size_t _len);
int tls_config_set_ciphers(struct tls_config *_config, const char *_ciphers);
int tls_config_set_dheparams(struct tls_config *_config, const char *_params);
int tls_config_set_ecdhecurve(struct tls_config *_config, const char *_name);
int tls_config_set_key_file(struct tls_config *_config, const char *_key_file);
int tls_config_set_key_mem(struct tls_config *_config, const uint8_t *_key,
    size_t _len);
int tls_config_set_keypair_file(struct tls_config *_config,
    const char *_cert_file, const char *_key_file);
int tls_config_set_keypair_mem(struct tls_config *_config, const uint8_t *_cert,
    size_t _cert_len, const uint8_t *_key, size_t _key_len);
void tls_config_set_protocols(struct tls_config *_config, uint32_t _protocols);
void tls_config_set_verify_depth(struct tls_config *_config, int _verify_depth);

void tls_config_prefer_ciphers_client(struct tls_config *_config);
void tls_config_prefer_ciphers_server(struct tls_config *_config);

void tls_config_insecure_noverifycert(struct tls_config *_config);
void tls_config_insecure_noverifyname(struct tls_config *_config);
void tls_config_insecure_noverifytime(struct tls_config *_config);
void tls_config_verify(struct tls_config *_config);

void tls_config_verify_client(struct tls_config *_config);
void tls_config_verify_client_optional(struct tls_config *_config);

void tls_config_clear_keys(struct tls_config *_config);
int tls_config_parse_protocols(uint32_t *_protocols, const char *_protostr);

struct tls *tls_client(void);
struct tls *tls_server(void);
int tls_configure(struct tls *_ctx, struct tls_config *_config);
void tls_reset(struct tls *_ctx);
void tls_free(struct tls *_ctx);

int tls_accept_fds(struct tls *_ctx, struct tls **_cctx, int _fd_read,
    int _fd_write);
int tls_accept_socket(struct tls *_ctx, struct tls **_cctx, int _socket);
int tls_connect(struct tls *_ctx, const char *_host, const char *_port);
int tls_connect_fds(struct tls *_ctx, int _fd_read, int _fd_write,
    const char *_servername);
int tls_connect_servername(struct tls *_ctx, const char *_host,
    const char *_port, const char *_servername);
int tls_connect_socket(struct tls *_ctx, int _s, const char *_servername);
int tls_handshake(struct tls *_ctx);
ssize_t tls_read(struct tls *_ctx, void *_buf, size_t _buflen);
ssize_t tls_write(struct tls *_ctx, const void *_buf, size_t _buflen);
int tls_close(struct tls *_ctx);

int tls_peer_cert_provided(struct tls *_ctx);
int tls_peer_cert_contains_name(struct tls *_ctx, const char *_name);

const char *tls_peer_cert_hash(struct tls *_ctx);
const char *tls_peer_cert_issuer(struct tls *_ctx);
const char *tls_peer_cert_subject(struct tls *_ctx);
time_t	tls_peer_cert_notbefore(struct tls *_ctx);
time_t	tls_peer_cert_notafter(struct tls *_ctx);

const char *tls_conn_version(struct tls *_ctx);
const char *tls_conn_cipher(struct tls *_ctx);
]])


--
-- Errors

local errors = require("levee.errors")


local error_base = errors.get(-1)
local Error_mt = {
	__tostring = error_base.__tostring,
	is = error_base.is,
	abort = error_base.abort,
}


function Error_mt:exit(code)
	io.stderr:write(tostring(self))
	io.stderr:write("\n")
	os.exit(code or 1)
end


function Error_mt:__index(key)
	local fields = {
		code = true,
		domain = true,
		name = true,
		msg = true, }

	if fields[key] then
		return self["_"..key]
	end

	local domain, name = key:match("is_([a-zA-Z0-9]+)_([a-zA-Z0-9]+)")
	if domain and name then return self:is(domain, name) end

	return Error_mt[key]
end


local function Error(obj, name)
	local self = { _domain = "tls" }

	if ffi.istype("struct tls_config", obj) then
		self._code = -30001
		self._name = name or "CONFIG"
		self._msg = ffi.string(C.tls_config_error(obj))
	elseif ffi.istype("struct tls", obj) then
		self._code = -30002
		self._name = name or "CONTEXT"
		self._msg = ffi.string(C.tls_error(obj))
	else
		self._code = -30000
		self._name = name or "GENERIC"
		self._msg = "generic TLS error"
	end

	return setmetatable(self, Error_mt)
end


--
-- Upgraded Read / Write Connection
--

local IO_RW_mt = require("levee.core.io")().RW_mt


local RW_mt = {}
for k, v in pairs(IO_RW_mt) do RW_mt[k] = v end
RW_mt.__index = RW_mt


function RW_mt:__WANT_POLL(rc, grace)
	if rc == C.TLS_WANT_POLLIN then
		local err, __, rc = self.r_ev:recv()
		if err or rc < 0 then
			if grace and rc == -1 then return nil, -1 end
			self:close()
			return errors.CLOSED
		end

	elseif rc == C.TLS_WANT_POLLOUT then
		local err, __, rc = self.w_ev:recv()
		if err or rc < 0 then
			self:close()
			return errors.CLOSED
		end

	else
		self:close()
		return Error(self.ctx, "CLIENT")
	end
end


function RW_mt:handshake()
	local rc = C.tls_handshake(self.ctx)
	if rc == -1 then return ffi.string(C.tls_error(self.ctx)) end
	if rc >= 0 then return nil, tonumber(rc) end

	local err, rc = self:__WANT_POLL(rc)
	if err then return err end

	return self:handshake()
end


function RW_mt:read(buf, len)
	if self.closed then return errors.CLOSED end

	if not len then len = ffi.sizeof(buf) end

	local rc = C.tls_read(self.ctx, buf, len)
	if rc > 0 then return nil, tonumber(rc) end

	if self.r_error or rc == 0 then
		self:close()
		return errors.CLOSED
	end

	local err, rc = self:__WANT_POLL(rc, not self.r_error)
	if err then return err end
	if rc then self.r_error = true end

	return self:read(buf, len)
end


function RW_mt:write(buf, len)
	if self.closed then return errors.CLOSED end

	if not len then
		if type(buf) == "cdata" then
			len = ffi.sizeof(buf)
		else
			len = #buf
		end
	end

	local rc = C.tls_write(self.ctx, buf, len)
	if rc >= 0 then return nil, tonumber(rc) end

	local err = self:__WANT_POLL(rc)
	if err then return err end

	return self:write(buf, len)
end


function RW_mt:writev(iov, n)
	-- TODO merge this with io.W_mt:writev
	if self.closed then return errors.CLOSED end

	local len
	local i, total = 0, 0

	while true do
		while true do
			len = ffi.C.levee_tls_writev(self.ctx, iov[i], n - i)
			if len > 0 then break end
			local err = errors.get(ffi.errno())
			if not err.is_system_EAGAIN then
				self:close()
				return err
			end
			self.w_ev:recv()
		end

		total = total + len

		while true do
			if iov[i].iov_len > len then break end
			len = len - iov[i].iov_len
			i = i + 1
			if i == n then
				assert(len == 0)
				self.hub:continue()
				return nil, total
			end
		end

		if len > 0 then
			iov[i].iov_base = iov[i].iov_base + len
			iov[i].iov_len = iov[i].iov_len - len
		end
	end
end


function RW_mt:close()
	if self.closed then return errors.CLOSED end

	self.closed = true

	while true do
		local rc = C.tls_close(self.ctx)
		if rc >= 0 then break end

		local err = self:__WANT_POLL(rc)
		if err then break end
	end

	-- clear closed so super:close will run
	self.closed = nil
	return IO_RW_mt.close(self)
end


local function RW(rw, config, ctx)
	rw.config = config
	rw.ctx = ctx
	return setmetatable(rw, RW_mt)
end


--
-- Server

local TLSServer_mt = {}
TLSServer_mt.__index = TLSServer_mt


function TLSServer_mt:__tostring()
	return string.format("levee.TLSServer: %p", self)
end


local ctx_tmp = ffi.new("struct tls *[1]")

function TLSServer_mt:upgrade(rw)
	if C.tls_accept_socket(self.ctx, ctx_tmp, rw.no) < 0 then
		return Error(ctx, "SERVER")
	end
	local ctx = ctx_tmp[0]
	ctx_tmp[0] = nil
	return nil, RW(rw, self.config, ctx)
end


--
-- Config

local Config_mt = {}
Config_mt.__index = Config_mt


function Config_mt:__tostring()
	return string.format("levee.TLSConfig: %p", self)
end


function Config_mt:server()
	local ctx = ffi.gc(C.tls_server(), C.tls_free)
	if ctx == nil then
		return errors.get(ffi.errno())
	end
	if C.tls_configure(ctx, self) < 0 then
		return Error(ctx, "SERVER")
	end
	return nil, setmetatable({
		ctx = ctx,
		config = self,
	}, TLSServer_mt)
end


function Config_mt:upgrade(rw, servname)
	local ctx = ffi.gc(C.tls_client(), C.tls_free)
	if ctx == nil then
		return errors.get(ffi.errno())
	end
	if C.tls_configure(ctx, self) < 0 or
		C.tls_connect_socket(ctx, rw.no, servname) < 0 then
		return Error(ctx, "CLIENT")
	end
	return nil, RW(rw, self, ctx)
end


--[[
Options:
  Certificate Authority:
    ca = BYTES            # root certificates from string
    ca_path = DIRECTORY   # directory searched for root certificates
    ca_file = FILE        # file containing the root certificates
  Certificate:
    cert = BYTES          # public certificate from string
    cert_file = FILE      # file containing the public certificate
  Key:
    key = BYTES           # private key from string
    key_file = FILE       # file containing the private key
  Ciphers:
    ciphers = "secure"    # use the secure ciphers only (default)
    ciphers = "compat"    # OpenSSL compatibility
    ciphers = "legacy"    # (not documented)
    ciphers = "insecure"  # all ciphers available
    ciphers = "all"       # same as "insecure"
    ciphers = STRING      # see CIPHERS section of openssl(1)
  DHE Params:
    dheparams = STRING    # (not documented)
  ECDHE Curve:
    ecdhecurve = STRING   # (not documented)
  Protocols:
    protocols = "TLSv1.0" # only TLSv1.0
    protocols = "TLSv1.1" # only TLSv1.1
    protocols = "TLSv1.2" # only TLSv1.2
    protocols = "ALL"     # all supported protocols
    protocols = "DEFAULT" # currently TLSv1.2
    protocols = LIST      # any combination of the above strings
  Verfiy Depth:
    verify_depth = NUMBER # limit verification depth (?)
  Server:
    server = {
      prefer_ciphers = "server"  # prefer client cipher list (less secure)
      prefer_ciphers = "client"  # prefer server cipher list (more secure, default)
      verify_client = true       # require client to send certificate
      verify_client = "optional" # enable client to send certificate
    }
  Insecure:
    insecure = {
      verify_cert = false        # disable certificate verification
      verify_name = false        # disable server name verification for client
      verify_time = false        # disable validity checking of certificates
    }
--]]


local protocols = {
	["TLSV1.0"] = C.TLS_PROTOCOL_TLSv1_0,
	["TLSV1.1"] = C.TLS_PROTOCOL_TLSv1_1,
	["TLSV1.2"] = C.TLS_PROTOCOL_TLSv1_2,
	TLSV1_0 = C.TLS_PROTOCOL_TLSv1_0,
	TLSV1_1 = C.TLS_PROTOCOL_TLSv1_1,
	TLSV1_2 = C.TLS_PROTOCOL_TLSv1_2,
	TLSV1 = C.TLS_PROTOCOL_TLSv1,
	ALL = C.TLS_PROTOCOLS_ALL,
	DEFAULT = C.TLS_PROTOCOLS_DEFAULT,
}


local function combine(val, options)
	if type(val) == "string" then
		return options[val:upper()]
	end
	if type(val) ~= "table" then return end
	local combined
	for i,k in ipairs(val) do
		if type(k) == "string" then
			local v = options[k:upper()]
			if v then
				combined = bit.bor(combined or 0, v)
			end
		end
	end
	return combined
end


local function Config(opts)
	local cfg = ffi.gc(C.tls_config_new(), C.tls_config_free)
	if not cfg then return errors.get(ffi.errno()) end
	if not opts then return nil, cfg end

	local val

	-- Certificate Authority
	val = opts.ca
	if type(val) == "string" then
		if C.tls_config_set_ca_mem(cfg, val, #val) < 0 then
			return Error(cfg)
		end
	else
		val = opts.ca_path
		if type(val) == "string" then
			if C.tls_config_set_ca_path(cfg, val) < 0 then
				return Error(cfg)
			end
		else
			val = opts.ca_file
			if type(val) == "string" then
				if C.tls_config_set_ca_file(cfg, val) < 0 then
					return Error(cfg)
				end
			end
		end
	end

	-- Certifcate
	val = opts.cert
	if type(val) == "string" then
		if C.tls_config_set_cert_mem(cfg, val, #val) < 0 then
			return Error(cfg)
		end
	else
		val = opts.cert_file
		if type(val) == "string" then
			if C.tls_config_set_cert_file(cfg, val) < 0 then
				return Error(cfg)
			end
		end
	end

	-- Key
	val = opts.key
	if type(val) == "string" then
		if C.tls_config_set_key_mem(cfg, val, #val) < 0 then
			return Error(cfg)
		end
	else
		val = opts.key_file
		if type(val) == "string" then
			if C.tls_config_set_key_file(cfg, val) < 0 then
				return Error(cfg)
			end
		end
	end

	-- Ciphers
	val = opts.ciphers
	if type(val) == "string" then
		if C.tls_config_set_ciphers(cfg, val) < 0 then
			return Error(cfg)
		end
	end

	-- DHE Params
	val = opts.dheparams
	if type(val) == "string" then
		if C.tls_config_set_dheparams(cfg, val) < 0 then
			return Error(cfg)
		end
	end

	-- ECDHE Curve
	val = opts.ecdhecurve
	if type(val) == "string" then
		if C.tls_config_set_ecdhecurve(cfg, val) < 0 then
			return Error(cfg)
		end
	end

	-- Protocols
	val = combine(opts.protocols, protocols)
	if type(val) == "number" then
		C.tls_config_set_protocols(cfg, val)
	end

	-- Verify Depth
	val = opts.verify_depth
	if type(val) == "number" then
		C.tls_config_set_verify_depth(cfg, val);
	end

	local server = opts.server
	if type(server) == "table" then
		if server.prefer_ciphers == "server" then
			C.tls_config_prefer_ciphers_server(cfg)
		elseif server.prefer_ciphers == "client" then
			C.tls_config_prefer_ciphers_client(cfg)
		end
		if server.verify_client == true then
			C.tls_config_verify_client(cfg)
		elseif server.verify_client == "optional" then
			C.tls_config_verify_client_optional(cfg)
		end
	end

	local insecure = opts.insecure
	if type(insecure) == "table" then
		if insecure.verify_cert == false then
			C.tls_config_insecure_noverifycert(cfg)
		end
		if insecure.verify_name == false then
			C.tls_config_insecure_noverifyname(cfg)
		end
		if insecure.verify_time == false then
			C.tls_config_insecure_noverifytime(cfg)
		end
	end

	return nil, cfg
end


ffi.metatype("struct tls_config", Config_mt)

if C.tls_init() < 0 then
	io.stderr:write("libtls failed to initialize: %s\n" % C.strerror(ffi.errno()))
	os.exit(1)
end


local M = {}
M.Config = Config
return M
