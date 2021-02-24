# Valhala Window - (VWindow)
A simple GLFW3 GLFWwindow wrapper abstraction.

## What's different
VWindow encapsulates GLFWwindow's instance in a class Window. All GLFW's
functions are easily accessible with it's instance making the programm less
verbose and easier to write. The main window events are also available and
working with delegates.

### Example
```d
glfwInit();
scope(exit) glfwTerminate();

// creates a default window
// width: 1280
// height: 720
// title: "Valhala"
auto win = new Window();

// events are easy to set
win.cursorPosCallback = (Window, double x, double y) => writefln!"Cursor moved at %s,%s"(x,y);
win.posCallback = (Window,int,int) {};

// to remove an event
win.posCallback = null;

win.swapInterval = 1;

// main loop
while (!win.shouldClose)
{
	glfwPoolEvents();
	win.swapBuffers();
}
```

```d
glfwInit();
scope(exit) glfwTerminate();

// creates a windowed window and doesn't make it's context current
auto win = new Window(ivec(1280,720), "title", No.fullscreen, No.makeCurrent)

win.swapInterval = 1;

// main loop
while (!win.shouldClose)
{
	glfwPoolEvents();
	win.swapBuffers();
}
```
## Libraries used
[Bindbc-glfw](https://github.com/BindBC/bindbc-glfw)

## License
Licensed under:
[MIT](https://github.com/ValhalaLib/valhala_window/blob/master/LICENSE)

## Contribution
If you are interested in project and want to improve it, creating issues and
pull requests are highly appretiated!
