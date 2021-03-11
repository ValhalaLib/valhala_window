module vwindow.window;

import std.conv : to;
import std.exception : assumeWontThrow;
import std.format : format;
import std.string : capitalize, toLower, fromStringz, toStringz, toUpper;
import std.typecons : Flag, No, Tuple, tuple, Yes;
import std.traits : FunctionAttribute, functionAttributes, functionLinkage, SetFunctionAttributes;
import std.traits : isFunctionPointer, isDelegate, ReturnType, Parameters;

import bindbc.glfw.bindstatic;
import bindbc.glfw.types;

version(vwindow_unittest) import aurorafw.unit.assertion;


/**
 * Window user pointer data. Every Window sets its GLFWwindow's user pointer to
 *     an instance of this.It's purpose is to connect the Window's instance to
 *     GLFWwindow's instance. Additionally it contains an extra field for a user
 *     to use like the GLFWwindow's user pointer.
 */
struct UserptrData
{
	private Window window;
	void* userptr;
}


///
struct FrameSize
{
	int left;
	int top;
	int right;
	int bottom;
}


///
struct Vec2(T)
{
	T a;
	T b;

	alias x = a;
	alias xpos = a;
	alias width = a;
	alias y = b;
	alias ypos = b;
	alias height = b;
}


alias ivec2 = Vec2!int;
alias uvec2 = Vec2!uint;
alias fvec2 = Vec2!float;
alias dvec2 = Vec2!double;


@safe pure
@("window: Vec2")
unittest
{
	auto vec = ivec2(2,3);
	assertEquals(vec.x, 2);
	assertEquals(vec.xpos, 2);
	assertEquals(vec.width, 2);

	assertEquals(vec.y, 3);
	assertEquals(vec.ypos, 3);
	assertEquals(vec.height, 3);

	assertFalse(__traits(compiles, vec.z));
}


///
private template glfwCallback(alias glfwcallback,alias extcallback)
{
	enum glfwCallback = format!q{%s(this._window, fun is null ? null : &%s);}(__traits(identifier,glfwcallback),__traits(identifier,extcallback));
}


///
class Window
{
	@trusted
	this(
		in int width = 1280,
		in int height = 720,
		in string title = "Valhala",
		Flag!"fullscreen" fullscreen = No.fullscreen,
		Flag!"makeCurrent" makeCurrent = Yes.makeCurrent
	) {
		if (!fullscreen)
		{
			_window = glfwCreateWindow(width, height, title.toStringz(), null, null);
		}
		else
		{
			// FIXME: abstract this
			GLFWmonitor* monitor = glfwGetPrimaryMonitor();
			const GLFWvidmode* vidmode = glfwGetVideoMode(monitor);

			glfwWindowHint(GLFW_RED_BITS, vidmode.redBits);
			glfwWindowHint(GLFW_GREEN_BITS, vidmode.greenBits);
			glfwWindowHint(GLFW_BLUE_BITS, vidmode.blueBits);
			glfwWindowHint(GLFW_REFRESH_RATE, vidmode.refreshRate);

			_window = glfwCreateWindow(vidmode.width, vidmode.height, title.toStringz(), monitor, null);
		}

		this._title = title;
		this._userptrdata = UserptrData(this);

		if (makeCurrent)
			glfwMakeContextCurrent(_window);


		glfwSetWindowUserPointer(_window, cast(void*) &_userptrdata);
	}

	@trusted
	this(
		in ivec2 wsize,
		in string title = "Valhala",
		Flag!"fullscreen" fullscreen = No.fullscreen,
		Flag!"makeCurrent" makeCurrent = Yes.makeCurrent
	) {
		this(wsize.width, wsize.height, title, fullscreen, makeCurrent);
	}

	@trusted
	~this()
	{
		glfwDestroyWindow(_window);
	}


	@trusted @property
	void aspectRatio(in int number, in int denum)
	{
		glfwSetWindowAspectRatio(this._window, number, denum);
	}

	@trusted @property
	void charCallback(void delegate(Window,uint) fun)
	{
		mixin (glfwCallback!(glfwSetCharCallback, _extCharCallback));
		this._charfun = fun;
	}

	@trusted @property
	void charModsCallback(void delegate(Window,uint,int) fun)
	{
		mixin (glfwCallback!(glfwSetCharModsCallback, _extCharModsCallback));
		this._charmodsfun = fun;
	}

	@trusted @property
	void clipboardString(in string str)
	{
		glfwSetClipboardString(this._window, str.toStringz);
	}

	@trusted @property
	string clipboardString()
	{
		auto cstr = glfwGetClipboardString(this._window);
		return cstr is null ? "" : cstr.fromStringz.to!string;
	}

	@trusted @property
	void closeCallback(void delegate(Window) fun)
	{
		mixin (glfwCallback!(glfwSetWindowCloseCallback, _extCloseCallback));
		this._closefun = fun;
	}

	@trusted @property
	fvec2 contentScale()
	{
		fvec2 scale;
		glfwGetWindowContentScale(this.window, &scale.x, &scale.y);
		return scale;
	}

	@trusted @property
	void contentScaleCallback(void delegate(Window,float,float) fun)
	{
		mixin (glfwCallback!(glfwSetWindowContentScaleCallback, _extContentScaleCallback));
		this._contentscalefun = fun;
	}

	@trusted @property
	void cursor(GLFWcursor* cursor)
	{
		glfwSetCursor(this._window, cursor);
	}

	@trusted @property
	void cursorEnterCallback(void delegate(Window,bool) fun)
	{
		mixin (glfwCallback!(glfwSetCursorEnterCallback, _extCursorEnterCallback));
		this._cursorenterfun = fun;
	}

	@trusted @property
	void cursorPos(in double x, in double y)
	{
		glfwSetCursorPos(this._window, x, y);
	}

	@trusted @property
	void cursorPos(dvec2 pos)
	{
		glfwSetCursorPos(this._window, pos.x, pos.y);
	}

	@trusted @property
	dvec2 cursorPos()
	{
		dvec2 pos;
		glfwGetCursorPos(this._window, &pos.x, &pos.y);
		return pos;
	}

	@trusted @property
	void cursorPosCallback(void delegate(Window,double,double) fun)
	{
		mixin (glfwCallback!(glfwSetCursorPosCallback, _extCursorPosCallback));
		this._cursorposfun = fun;
	}

	@trusted @property
	void dropCallback(void delegate(Window,string[]) fun)
	{
		mixin (glfwCallback!(glfwSetDropCallback, _extDropCallback));
		this._dropfun = fun;
	}

	@trusted @property
	void time(in double time)
	{
		glfwSetTime(time);
	}

	@trusted @property
	double time()
	{
		return glfwGetTime();
	}

	@trusted
	void focus()
	{
		glfwFocusWindow(this._window);
	}

	@trusted @property
	void focusCallback(void delegate(Window,bool) fun)
	{
		mixin (glfwCallback!(glfwSetWindowFocusCallback, _extFocusCallback));
		this._focusfun = fun;
	}

	@trusted @property
	void framebufferSizeCallback(void delegate(Window,int,int) fun)
	{
		mixin (glfwCallback!(glfwSetFramebufferSizeCallback,_extFramebufferSizeCallback));
		this._framebuffersizefun = fun;
	}

	@trusted @property
	int framebufferHeight()
	{
		int fbheight;
		glfwGetFramebufferSize(_window, null, &fbheight);
		return fbheight;
	}

	@trusted @property
	ivec2 framebufferSize()
	{
		ivec2 fbsize;
		glfwGetFramebufferSize(_window, &fbsize.width, &fbsize.height);
		return fbsize;
	}

	@trusted @property
	int framebufferWidth()
	{
		int fbwidth;
		glfwGetFramebufferSize(_window, &fbwidth, null);
		return fbwidth;
	}

	@trusted @property
	FrameSize frameSize()
	{
		FrameSize fsize;
		glfwGetWindowFrameSize(this._window, &fsize.left, &fsize.top, &fsize.right, &fsize.bottom);
		return fsize;
	}

	@trusted
	void height(in int h)
	{
		size(width, h);
	}

	@trusted
	int height()
	{
		int h;
		glfwGetWindowSize(_window, null, &h);
		return h;
	}

	@trusted
	void hide()
	{
		glfwHideWindow(this._window);
	}

	@trusted
	void iconify()
	{
		glfwIconifyWindow(_window);
	}

	@trusted @property
	void iconifyCallback(void delegate(Window,bool) fun)
	{
		mixin (glfwCallback!(glfwSetWindowIconifyCallback, _extIconifyCallback));
		this._iconifyfun = fun;
	}

	@trusted @property
	void keyCallback(void delegate(Window,int,int,int,int) fun)
	{
		mixin (glfwCallback!(glfwSetKeyCallback, _extKeyCallback));
		this._keyfun = fun;
	}

	@trusted
	void makeContextCurrent()
	{
		glfwMakeContextCurrent(_window);
	}

	@trusted
	void maximize()
	{
		glfwMaximizeWindow(_window);
	}

	@trusted @property
	void maximizeCallback(void delegate(Window,bool) fun)
	{
		mixin (glfwCallback!(glfwSetWindowMaximizeCallback, _extMaximizeCallback));
		this._maximizefun = fun;
	}

	@trusted
	void monitor(
		GLFWmonitor* glfwmon,
		in int posx,
		in int posy,
		in int width,
		in int height,
		in int refreshRate
	) {
		glfwSetWindowMonitor(this._window, glfwmon, posx, posy, width, height, refreshRate);
	}

	@trusted
	void monitor(GLFWmonitor* glfwmon, ivec2 pos, ivec2 size, in int refreshRate)
	{
		monitor(glfwmon, pos.x, pos.y, size.width, size.height, refreshRate);
	}

	@trusted
	GLFWmonitor* monitor()
	{
		return glfwGetWindowMonitor(this._window);
	}

	@trusted @property
	void mouseButtonCallback(void delegate(Window,int,int,int) fun)
	{
		mixin (glfwCallback!(glfwSetMouseButtonCallback, _extMouseButtonCallback));
		this._mousebuttonfun = fun;
	}

	@trusted @property
	void opacity(in float o)
	{
		glfwSetWindowOpacity(this._window, o);
	}

	@trusted @property
	float opacity()
	{
		return glfwGetWindowOpacity(this._window);
	}

	@trusted @property
	void pos(in int x, in int y)
	{
		glfwSetWindowPos(_window, x, y);
	}

	@trusted @property
	void pos(in ivec2 wpos)
	{
		glfwSetWindowPos(_window, wpos.x, wpos.y);
	}

	@trusted @property
	ivec2 pos()
	{
		ivec2 pos;
		glfwGetWindowPos(_window, &pos.x, &pos.y);
		return pos;
	}

	@trusted @property
	void posCallback(void delegate(Window,int,int) fun)
	{
		mixin (glfwCallback!(glfwSetWindowPosCallback, _extPosCallback));
		this._posfun = fun;
	}

	@trusted @property
	void refreshCallback(void delegate(Window) fun)
	{
		mixin (glfwCallback!(glfwSetWindowRefreshCallback, _extRefreshCallback));
		this._refreshfun = fun;
	}

	@trusted
	void requestAttention()
	{
		glfwRequestWindowAttention(this._window);
	}

	@trusted
	void restore()
	{
		glfwRestoreWindow(this._window);
	}

	@trusted @property
	void scrollCallback(void delegate(Window,double,double) fun)
	{
		mixin (glfwCallback!(glfwSetScrollCallback, _extScrollCallback));
		this._scrollfun = fun;
	}

	@trusted @property
	void shouldClose(bool action)
	{
		glfwSetWindowShouldClose(_window, action);
	}

	@trusted @property
	bool shouldClose()
	{
		return cast(bool) glfwWindowShouldClose(_window);
	}

	@trusted
	void show()
	{
		glfwShowWindow(this._window);
	}

	@trusted @property
	void size(in int w, in int h)
	{
		glfwSetWindowSize(_window, w, h);
	}

	@trusted @property
	void size(in ivec2 wsize)
	{
		size(wsize.width, wsize.height);
	}

	@trusted @property
	ivec2 size()
	{
		ivec2 wsize;
		glfwGetWindowSize(_window, &wsize.width, &wsize.height);
		return wsize;
	}

	@trusted @property
	void sizeCallback(void delegate(Window,int,int) fun)
	{
		mixin (glfwCallback!(glfwSetWindowSizeCallback,_extSizeCallback));
		this._sizefun = fun;
	}

	@trusted
	void sizeLimits(in int minWidth, in int minHeight, in int maxWidth, in int maxHeight)
	{
		glfwSetWindowSizeLimits(_window, minWidth, minHeight, maxWidth, maxHeight);
	}

	@trusted
	void sizeLimits(in ivec2 minLimits, in ivec2 maxLimits)
	{
		glfwSetWindowSizeLimits(_window, minLimits.width, minLimits.height, maxLimits.width, maxLimits.height);
	}

	@trusted @property
	void sizeLimitsMax(in ivec2 maxLimits)
	{
		glfwSetWindowSizeLimits(_window, GLFW_DONT_CARE, GLFW_DONT_CARE, maxLimits.width, maxLimits.height);
	}

	@trusted @property
	void sizeLimitsMin(in ivec2 minLimits)
	{
		glfwSetWindowSizeLimits(_window, minLimits.width, minLimits.height, GLFW_DONT_CARE, GLFW_DONT_CARE);
	}

	@trusted @property
	void sizeLimitsRemove()
	{
		glfwSetWindowSizeLimits(_window, GLFW_DONT_CARE, GLFW_DONT_CARE, GLFW_DONT_CARE, GLFW_DONT_CARE);
	}

	@trusted
	void swapBuffers()
	{
		glfwSwapBuffers(this._window);
	}

	@trusted @property
	void swapInterval(bool swap)
	{
		glfwSwapInterval(swap);
	}

	@trusted @property
	void title(in string title)
	{
		glfwSetWindowTitle(_window, title.toStringz());
		_title = title;
	}

	@trusted @property
	string title()
	{
		return _title;
	}

	@trusted @property
	void* userPointer()
	{
		return _userptrdata.userptr;
	}

	@trusted @property
	void userPointer(void* ptr)
	{
		_userptrdata.userptr = ptr;
	}

	@trusted @property
	void width(in int w)
	{
		size(w, height);
	}

	@trusted @property
	int width()
	{
		int w;
		glfwGetWindowSize(_window, &w, null);
		return w;
	}

	@system @property
	GLFWwindow* window()
	{
		return this._window;
	}

	@trusted @property
	void xpos(in int x)
	{
		glfwSetWindowPos(_window, x, ypos);
	}

	@trusted @property
	int xpos()
	{
		int x;
		glfwGetWindowPos(_window, &x, null);
		return x;
	}

	@trusted @property
	void ypos(in int y)
	{
		glfwSetWindowPos(_window, xpos, y);
	}

	@trusted @property
	int ypos()
	{
		int y;
		glfwGetWindowPos(_window, null, &y);
		return y;
	}

private:
	GLFWwindow* _window;
	string _title;
	UserptrData _userptrdata;
	void delegate(Window,uint) _charfun;
	void delegate(Window,uint,int) _charmodsfun;
	void delegate(Window,float,float) _contentscalefun;
	void delegate(Window) _closefun;
	void delegate(Window,bool) _cursorenterfun;
	void delegate(Window,double,double) _cursorposfun;
	void delegate(Window,string[]) _dropfun;
	void delegate(Window,bool) _focusfun;
	void delegate(Window,int,int) _framebuffersizefun;
	void delegate(Window,bool) _iconifyfun;
	void delegate(Window,int,int,int,int) _keyfun;
	void delegate(Window,bool) _maximizefun;
	void delegate(Window,int,int,int) _mousebuttonfun;
	void delegate(Window,int,int) _posfun;
	void delegate(Window) _refreshfun;
	void delegate(Window,double,double) _scrollfun;
	void delegate(Window,int,int) _sizefun;
}


/**
 * Takes a GLFWwindow and gets it's Window instance if it has one. A Window
 *     instance is associated with GLFWwindow only if the GLFWwindow was created
 *     using Window.
 *
 * Params: glfwwin = GLFWwindow* to get Window from.
 *
 * Returns: Window if associated with glfwwin, asserts if UserPointer is null,
 *     otherwise it leads to undefined behaviour.
 */
@system nothrow
Window fromGlfwWindow(GLFWwindow* glfwwin)
{
	UserptrData* data = cast(UserptrData*) glfwGetWindowUserPointer(glfwwin);
	assert(data !is null);
	return data.window;
}

package extern (C) nothrow
{
	@trusted
	void _extCharCallback(GLFWwindow* glfwwin, uint codepoint)
	{
		auto win = fromGlfwWindow(glfwwin);
		win._charfun(win,codepoint).assumeWontThrow;
	}

	@trusted
	void _extCharModsCallback(GLFWwindow* glfwwin, uint codepoint, int mods)
	{
		auto win = fromGlfwWindow(glfwwin);
		win._charmodsfun(win,codepoint,mods).assumeWontThrow;
	}

	@trusted
	void _extContentScaleCallback(GLFWwindow* glfwwin, float xscale, float yscale)
	{
		auto win = fromGlfwWindow(glfwwin);
		win._contentscalefun(win,xscale,yscale).assumeWontThrow;
	}

	@trusted
	void _extCloseCallback(GLFWwindow* glfwwin)
	{
		auto win = fromGlfwWindow(glfwwin);
		win._closefun(win).assumeWontThrow;
	}

	@trusted
	void _extCursorPosCallback(GLFWwindow* glfwwin, double x, double y)
	{
		auto win = fromGlfwWindow(glfwwin);
		win._cursorposfun(win,x,y).assumeWontThrow;
	}

	@trusted
	void _extCursorEnterCallback(GLFWwindow* glfwwin, int entered)
	{
		auto win = fromGlfwWindow(glfwwin);
		win._cursorenterfun(win,cast(bool)entered).assumeWontThrow;
	}

	@trusted
	void _extDropCallback(GLFWwindow* glfwwin, int pathCount, const(char*)* paths)
	{
		auto win = fromGlfwWindow(glfwwin);
		win._dropfun(win,paths[0..pathCount].to!(string[])).assumeWontThrow;
	}

	@trusted
	void _extFocusCallback(GLFWwindow* glfwwin, int focused)
	{
		auto win = fromGlfwWindow(glfwwin);
		win._focusfun(win,cast(bool)focused).assumeWontThrow;
	}

	@trusted
	void _extFramebufferSizeCallback(GLFWwindow* glfwwin, int w, int h)
	{
		auto win = fromGlfwWindow(glfwwin);
		win._framebuffersizefun(win,w,h).assumeWontThrow;
	}

	@trusted
	void _extIconifyCallback(GLFWwindow* glfwwin, int iconified)
	{
		auto win = fromGlfwWindow(glfwwin);
		win._iconifyfun(win,cast(bool)iconified).assumeWontThrow;
	}

	@trusted
	void _extKeyCallback(GLFWwindow* glfwwin, int key, int scancode, int action, int mods)
	{
		auto win = fromGlfwWindow(glfwwin);
		win._keyfun(win,key,scancode,action,mods).assumeWontThrow;
	}

	@trusted
	void _extMaximizeCallback(GLFWwindow* glfwwin, int maximized)
	{
		auto win = fromGlfwWindow(glfwwin);
		win._maximizefun(win,cast(bool)maximized).assumeWontThrow;
	}

	@trusted
	void _extMouseButtonCallback(GLFWwindow* glfwwin, int button, int action, int mods)
	{
		auto win = fromGlfwWindow(glfwwin);
		win._mousebuttonfun(win,button,action,mods).assumeWontThrow;
	}

	@trusted
	void _extPosCallback(GLFWwindow* glfwwin, int x, int y)
	{
		auto win = fromGlfwWindow(glfwwin);
		win._posfun(win,x,y).assumeWontThrow;
	}

	@trusted
	void _extRefreshCallback(GLFWwindow* glfwwin)
	{
		auto win = fromGlfwWindow(glfwwin);
		win._refreshfun(win).assumeWontThrow;
	}

	@trusted
	void _extScrollCallback(GLFWwindow* glfwwin, double x, double y)
	{
		auto win = fromGlfwWindow(glfwwin);
		win._scrollfun(win,x,y).assumeWontThrow;
	}

	@trusted
	void _extSizeCallback(GLFWwindow* glfwwin, int w, int h)
	{
		auto win = fromGlfwWindow(glfwwin);
		win._sizefun(win,w,h).assumeWontThrow;
	}
}

@trusted
@("window: ctor")
unittest
{
	glfwInit();
	scope(exit) glfwTerminate();

	glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE);

	{
		glfwWindowHint(GLFW_RESIZABLE, GLFW_FALSE);
		scope win = new Window();
		assertEquals(ivec2(1280,720), win.size);
		assertEquals("Valhala", win.title);
		assertEquals(win._window, glfwGetCurrentContext());
	}

	{
		GLFWmonitor* monitor = glfwGetPrimaryMonitor();
		const GLFWvidmode* vidmode = glfwGetVideoMode(monitor);
		scope win = new Window(ivec2(900,600), "test", Yes.fullscreen, No.makeCurrent);
		assertEquals(ivec2(vidmode.width, vidmode.height), win.size);
		assertEquals("test", win.title);
		assertEquals(null, glfwGetCurrentContext());
	}
}

@trusted
@("window: posCallback")
unittest
{
	glfwInit();
	scope(exit) glfwTerminate();

	// size test delegates
	void delegate(Window,int,int) dg1;
	void delegate(Window,int,int) dg2;

	// make a floating invisible window
	glfwWindowHint(GLFW_RESIZABLE, GLFW_FALSE);
	glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE);

	scope win = new Window();

	win.pos(15,20);
	dg1 = (Window win, int x, int y) {
		assertEquals(ivec2(15,20), ivec2(x,y));
		win.posCallback = dg2;
	};

	win.pos = ivec2(67,421);
	dg2 = (Window win, int x, int y) {
		assertEquals(ivec2(67,421), ivec2(x,y));
		win.shouldClose = true;
	};

	// sets first test
	win.posCallback = dg1;

	// start updating changed positions
	while(!win.shouldClose) glfwPollEvents();
}

@trusted
@("window: sizeCallback")
unittest
{
	glfwInit();
	scope(exit) glfwTerminate();

	// size test delegates
	void delegate(Window,int,int) dg1;
	void delegate(Window,int,int) dg2;
	void delegate(Window,int,int) dg3;

	// make a floating invisible window
	glfwWindowHint(GLFW_RESIZABLE, GLFW_FALSE);
	glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE);

	scope win = new Window();
	assertEquals(1280, win.width);
	assertEquals( 720, win.height);
	assertEquals(ivec2(1280,720), win.size);

	win.size(1080,960);
	dg1 = (Window win, int w, int h) {
		assertEquals(ivec2(1080,960), ivec2(w,h));
		win.sizeCallback = dg2;
	};

	win.size = ivec2(900,600);
	dg2 = (Window win, int w, int h) {
		assertEquals(ivec2(900,600), ivec2(w,h));
		win.sizeCallback = dg3;
	};

	win.width = 1280;
	win.height = 720;
	dg3 = (Window win, int w, int h) {
		assertEquals(ivec2(1280,720), ivec2(w,h));
		win.shouldClose = true;
	};

	// sets first test
	win.sizeCallback = dg1;

	// start updating changed sizes
	while(!win.shouldClose) {
		glfwPollEvents();
	}
}
