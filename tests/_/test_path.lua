local _ = require("levee")._


return {
	test_dirname = function()
		assert.equal(_.path.dirname("/usr/bin/foo"), "/usr/bin")
		assert.equal(_.path.dirname("/usr/bin/foo", 2), "/usr")
	end,

	test_basename = function()
		assert.equal(_.path.basename("/usr/bin/foo"), "foo")
		assert.equal(_.path.basename("/usr/bin/foo", 2), "bin/foo")
	end,

	test_procname = function()
		local err, s = _.path.procname()
		assert(not err)
		assert.equal(_.path.basename(s), "levee")
	end,

	test_envname = function()
		local err, s = _.path.envname("vi")
		assert(not err)
		assert.equal(_.path.basename(s), "vi")
	end,

	test_match = function()
		assert(_.path.match("test.c", "test.{cpp,c}"))
		assert(_.path.match("test.cpp", "test.{c,cpp}"))
		assert(_.path.match("test-abc.c", "test-abc.*"))
		assert(_.path.match("test-abc.c", "test-*.c"))
		assert(_.path.match("test-abc.c", "test-*.*"))
		assert(_.path.match("test-abc.c", "test-*.[ch]"))
		assert(_.path.match("test-abc.cpp", "test-*.[ch]pp"))
		assert(_.path.match("test-abc.c", "{test,value}-{abc,xyz}.{c,h}"))
		assert(_.path.match("value-xyz.h", "{test,value}-{abc,xyz}.{c,h}"))
		assert(_.path.match("/test/value", "/tes*/value"))

		assert(not _.path.match("test.c", "test.cpp"))
		assert(not _.path.match("test.cpp", "test.{c,o}"))
		assert(not _.path.match("test.c", "test.{cpp,o}"))
		assert(not _.path.match("test.c", "test*"))
		assert(not _.path.match("/test/value", "/tes*"))
		assert(not _.path.match("/test/value", "/tes*value"))
	end,

	test_join = function()
		assert.equal(_.path.join("/some/path/to/", "../up1.txt"),
			"/some/path/up1.txt")
		assert.equal(_.path.join("/some/path/to/", "../../up2.txt"),
			"/some/up2.txt")
		assert.equal(_.path.join("/some/path/to/", "/root.txt"),
			"/root.txt")
		assert.equal(_.path.join("/some/path/to/", "./current.txt"),
			"/some/path/to/current.txt")
		assert.equal(_.path.join("", "file.txt"),
			"file.txt")
		assert.equal(_.path.join("some", "file.txt"),
			"some/file.txt")
		assert.equal(_.path.join("some/", "../file.txt"),
			"file.txt")
		assert.equal(_.path.join("/", "file.txt"),
			"/file.txt")
		assert.equal(_.path.join("/test", ""),
			"/test")
		assert.equal(_.path.join("/test", "some", "thing"),
			"/test/some/thing")
		assert.equal(_.path.join("/test", "some", "/thing"),
			"/thing")
		assert.equal(_.path.join("/test", "some", "../thing", "./stuff"),
			"/test/thing/stuff")
	end,

	test_clean = function()
		assert.equal(_.path.clean("/some/path/../other/file.txt"),
			"/some/other/file.txt")
		assert.equal(_.path.clean("/some/path/../../other/file.txt"),
			"/other/file.txt")
		assert.equal(_.path.clean("/some/path/../../../other/file.txt"),
			"/other/file.txt")
		assert.equal(_.path.clean("../file.txt"),
			"../file.txt")
		assert.equal(_.path.clean("../../file.txt"),
			"../../file.txt")
		assert.equal(_.path.clean("/../file.txt"),
			"/file.txt")
		assert.equal(_.path.clean("/../../file.txt"),
			"/file.txt")
		assert.equal(_.path.clean("/some/./file.txt"),
			"/some/file.txt")
		assert.equal(_.path.clean("/some/././file.txt"),
			"/some/file.txt")
		assert.equal(_.path.clean("//some/file.txt"),
			"/some/file.txt")
		assert.equal(_.path.clean("/some//file.txt"),
			"/some/file.txt")
		assert.equal(_.path.clean("/a/b/c/./../../g"),
			"/a/g")
		assert.equal(_.path.clean("."),
			".")
		assert.equal(_.path.clean("/"),
			"/")
		assert.equal(_.path.clean(""),
			".")
		assert.equal(_.path.join("//"),
			"/")
	end,

	test_pop = function()
		assert.equal(_.path.pop("/path/to/file.txt", 1), "/path/to")
		assert.equal(_.path.pop("/path/to/file.txt", 2), "/path")
		assert.equal(_.path.pop("/path/to/file.txt", 3), "/")
		assert.equal(_.path.pop("/path/to/file.txt", 4), "")
		assert.equal(_.path.pop("path/to/file.txt", 1), "path/to")
		assert.equal(_.path.pop("path/to/file.txt", 2), "path")
		assert.equal(_.path.pop("path/to/file.txt", 3), "")
	end,

	test_split = function()
		local a, b

		a, b = _.path.split("/path/to/file.txt", 1)
		assert.equal(a, "/path/to")
		assert.equal(b, "file.txt")

		a, b = _.path.split("/path/to/file.txt", 2)
		assert.equal(a, "/path")
		assert.equal(b, "to/file.txt")

		a, b = _.path.split("/path/to/file.txt", 3)
		assert.equal(a, "/")
		assert.equal(b, "path/to/file.txt")

		a, b = _.path.split("/path/to/file.txt", 4)
		assert.equal(a, "")
		assert.equal(b, "/path/to/file.txt")

		a, b = _.path.split("/path/to/file.txt", 5)
		assert.equal(a, "")
		assert.equal(b, "/path/to/file.txt")

		a, b = _.path.split("/test/path/", 1)
		assert.equal(a, "/test/path")
		assert.equal(b, "")

		a, b = _.path.split("/test/path/", 2)
		assert.equal(a, "/test")
		assert.equal(b, "path/")

		a, b = _.path.split("/path/to/file.txt", -1)
		assert.equal(a, "/")
		assert.equal(b, "path/to/file.txt")

		a, b = _.path.split("/path/to/file.txt", -2)
		assert.equal(a, "/path")
		assert.equal(b, "to/file.txt")

		a, b = _.path.split("/path/to/file.txt", -3)
		assert.equal(a, "/path/to")
		assert.equal(b, "file.txt")

		a, b = _.path.split("/path/to/file.txt", -4)
		assert.equal(a, "/path/to/file.txt")
		assert.equal(b, "")

		a, b = _.path.split("/path/to/file.txt", -5)
		assert.equal(a, "/path/to/file.txt")
		assert.equal(b, "")

		a, b = _.path.split("path/to/file.txt", -1)
		assert.equal(a, "path")
		assert.equal(b, "to/file.txt")

		a, b = _.path.split("path/to/file.txt", -2)
		assert.equal(a, "path/to")
		assert.equal(b, "file.txt")

		a, b = _.path.split("path/to/file.txt", -3)
		assert.equal(a, "path/to/file.txt")
		assert.equal(b, "")

		a, b = _.path.split("path/to/file.txt", -4)
		assert.equal(a, "path/to/file.txt")
		assert.equal(b, "")

		a, b = _.path.split("/test/path", -1)
		assert.equal(a, "/")
		assert.equal(b, "test/path")

		a, b = _.path.split("/test/path", -2)
		assert.equal(a, "/test")
		assert.equal(b, "path")

		a, b = _.path.split("/test/path", -3)
		assert.equal(a, "/test/path")
		assert.equal(b, "")

		a, b = _.path.split("/test/path", -4)
		assert.equal(a, "/test/path")
		assert.equal(b, "")

		a, b = _.path.split("/test/path/", -1)
		assert.equal(a, "/")
		assert.equal(b, "test/path/")

		a, b = _.path.split("/test/path/", -2)
		assert.equal(a, "/test")
		assert.equal(b, "path/")

		a, b = _.path.split("/test/path/", -3)
		assert.equal(a, "/test/path")
		assert.equal(b, "")

		a, b = _.path.split("/test/path/", -4)
		assert.equal(a, "/test/path")
		assert.equal(b, "")

		a, b = _.path.split("/test", 1)
		assert.equal(a, "/")
		assert.equal(b, "test")

		a, b = _.path.split("/test", 2)
		assert.equal(a, "")
		assert.equal(b, "/test")

		a, b = _.path.split("/test", -1)
		assert.equal(a, "/")
		assert.equal(b, "test")

		a, b = _.path.split("/test", -2)
		assert.equal(a, "/test")
		assert.equal(b, "")

		a, b = _.path.split("/", 1)
		assert.equal(a, "/")
		assert.equal(b, "")

		a, b = _.path.split("/", 2)
		assert.equal(a, "")
		assert.equal(b, "/")

		a, b = _.path.split("/", -1)
		assert.equal(a, "")
		assert.equal(b, "/")

		a, b = _.path.split("/", -2)
		assert.equal(a, "/")
		assert.equal(b, "")

		a, b = _.path.split("test", 1)
		assert.equal(a, "")
		assert.equal(b, "test")

		a, b = _.path.split("test", 2)
		assert.equal(a, "")
		assert.equal(b, "test")

		a, b = _.path.split("test", -1)
		assert.equal(a, "test")
		assert.equal(b, "")

		a, b = _.path.split("test", -2)
		assert.equal(a, "test")
		assert.equal(b, "")

		a, b = _.path.split("", 1)
		assert.equal(a, "")
		assert.equal(b, "")

		a, b = _.path.split("", 2)
		assert.equal(a, "")
		assert.equal(b, "")

		a, b = _.path.split("", -1)
		assert.equal(a, "")
		assert.equal(b, "")

		a, b = _.path.split("", -2)
		assert.equal(a, "")
		assert.equal(b, "")
	end,

	test_splitext = function()
		local a, b

		a, b = _.path.splitext("file.txt")
		assert.equal(a, "file")
		assert.equal(b, "txt")

		a, b = _.path.splitext("/path/to/file.txt")
		assert.equal(a, "/path/to/file")
		assert.equal(b, "txt")
	end,

	test_exists = function()
		local path = os.tmpname()
		assert(_.path.exists(path))
		os.remove(path)
		assert(not _.path.exists(path))
	end,

	test_Path = function()
		local tmp = _.path.Path:tmpdir()
		assert(tmp:exists())
		assert(tmp:is_dir())
		assert(not tmp:remove())
		assert(tmp:exists())
		assert(tmp:remove(true))
		assert(not tmp:exists())
	end,
}
