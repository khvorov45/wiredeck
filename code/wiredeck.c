#include <stdint.h>
#include "SDL.h"

#define true 1
#define false 0
#define function static

typedef uint8_t u8;
typedef int32_t b32;
typedef int32_t i32;
typedef float f32;

typedef struct InputKey {
	i32 halfTransitionCount;
	b32 endedDown;
} InputKey;

typedef enum InputKeyID {
	InputKeyID_MouseLeft,
	InputKeyID_Count,
} InputKeyID;

typedef struct Input {
	InputKey keys[InputKeyID_Count];
	i32 cursorX;
	i32 cursorY;
} Input;

typedef enum UIWindowID {
	UIWindowID_1,
	UIWindowID_2,
	UIWindowID_Count,
} UIWindowID;

typedef struct UIWindow {
	SDL_Rect rect;
	SDL_Color color;
	b32 isDragged;
	i32 dragOffsetFromTopleftX;
	i32 dragOffsetFromTopleftY;
} UIWindow;

typedef struct UI {
	UIWindowID windowOrder[UIWindowID_Count];
	UIWindow windows[UIWindowID_Count];
} UI;

void
uiInit(UI* ui) {
	SDL_memset(ui, 0, sizeof(UI));

	for (i32 id = 0; id < UIWindowID_Count; id += 1) {
		ui->windowOrder[id] = id;
	}

	{
		UIWindow win = {.rect = {.x = 0, .y = 0, .w = 200, .h = 100}, .color = {.r = 255, .g = 0, .b = 0, .a = 255}};
		ui->windows[UIWindowID_1] = win;
	}

	{
		UIWindow win = {.rect = {.x = 100, .y = 100, .w = 100, .h = 200}, .color = {.r = 0, .g = 255, .b = 0, .a = 255}};
		ui->windows[UIWindowID_2] = win;
	}
}

b32
pointInRect(i32 pointX, i32 pointY, SDL_Rect rect) {
	i32 rectRight = rect.x + rect.w;
	i32 rectBottom = rect.y + rect.h;
	b32 inX = pointX >= rect.x && pointX < rectRight;
	b32 inY = pointY >= rect.y && pointY < rectBottom;
	b32 result = inX && inY;
	return result;
}

void
clearHalfTransitionCounts(Input* input) {
	for (i32 keyIndex = 0; keyIndex < InputKeyID_Count; keyIndex += 1) {
		InputKey* key = input->keys + keyIndex;
		key->halfTransitionCount = 0;
	}
}

void
recordKey(Input* input, InputKeyID keyID, b32 down) {
	InputKey* key = input->keys + keyID;
	key->halfTransitionCount += 1;
	key->endedDown = down;
}

b32
wasPressed(Input* input, InputKeyID keyID) {
	InputKey* key = input->keys + keyID;
	b32 result = key->halfTransitionCount > 1 || (key->halfTransitionCount == 1 && key->endedDown);
	return result;
}

b32
wasUnpressed(Input* input, InputKeyID keyID) {
	InputKey* key = input->keys + keyID;
	b32 result = key->halfTransitionCount > 1 || (key->halfTransitionCount == 1 && !key->endedDown);
	return result;
}

void
uiMoveWindowToFront(UI* ui, UIWindowID winID) {
	i32 winOrderIndex = 0;
	for (; winOrderIndex < UIWindowID_Count; winOrderIndex++) {
		if (ui->windowOrder[winOrderIndex] == winID) {
			break;
		}
	}

	for (; winOrderIndex < UIWindowID_Count - 1; winOrderIndex++) {
		ui->windowOrder[winOrderIndex] = ui->windowOrder[winOrderIndex + 1];
		ui->windowOrder[winOrderIndex + 1] = winID;
	}
}

void
uiWindowUpdate(UI* ui, UIWindowID winID, Input* input) {

	UIWindow* win = ui->windows + winID;

	if (wasPressed(input, InputKeyID_MouseLeft) && pointInRect(input->cursorX, input->cursorY, win->rect)) {

		win->isDragged = true;
		win->dragOffsetFromTopleftX = input->cursorX - win->rect.x;
		win->dragOffsetFromTopleftY = input->cursorY - win->rect.y;
		win->color.b = 255;
		uiMoveWindowToFront(ui, winID);

	} else if (wasUnpressed(input, InputKeyID_MouseLeft)) {

		win->isDragged = false;
		win->dragOffsetFromTopleftX = 0;
		win->dragOffsetFromTopleftY = 0;
		win->color.b = 0;
	}

	if (win->isDragged) {
		win->rect.x = input->cursorX - win->dragOffsetFromTopleftX;
		win->rect.y = input->cursorY - win->dragOffsetFromTopleftY;
	}
}

void
drawRect(SDL_Renderer* sdlRenderer, SDL_Rect rect, SDL_Color color) {
	SDL_SetRenderDrawColor(sdlRenderer, color.r, color.g, color.b, color.a);
	SDL_RenderFillRect(sdlRenderer, &rect);
}

void
processEvent(SDL_Window* window, SDL_Event* event, b32* running, Input* input) {

	switch (event->type) {
	case SDL_QUIT: {*running = false;} break;

	case SDL_WINDOWEVENT: {
		if (event->window.event == SDL_WINDOWEVENT_CLOSE && event->window.windowID == SDL_GetWindowID(window)) {
			*running = false;
		}
	} break;

	case SDL_MOUSEMOTION: {
		input->cursorX = event->motion.x;
		input->cursorY = event->motion.y;
	} break;

	case SDL_MOUSEBUTTONDOWN: case SDL_MOUSEBUTTONUP: {
		b32 down = event->type == SDL_MOUSEBUTTONUP ? 0 : 1;
		InputKeyID keyID = InputKeyID_Count;
		switch (event->button.button) {
		case SDL_BUTTON_LEFT: {keyID = InputKeyID_MouseLeft;} break;
		}
		if (keyID != InputKeyID_Count) {
			recordKey(input, keyID, down);
		}
	}
	}
}

void
pollEvents(SDL_Window* window, b32* running, Input* input) {
	SDL_Event event;
	while (SDL_PollEvent(&event)) {
		processEvent(window, &event, running, input);
	}
}

int
SDL_main(int argc, char* argv[]) {
	if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER) == 0) {

		// NOTE(khvorov) I would like to clear the window before it shows up
		// at all but I haven't found a way to do that on Windows and have
		// the window work as expected.
		SDL_Window* sdlWindow = SDL_CreateWindow("wiredeck", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 1000, 1000, SDL_WINDOW_RESIZABLE);
		if (sdlWindow) {

			SDL_Renderer* sdlRenderer = SDL_CreateRenderer(sdlWindow, -1, SDL_RENDERER_PRESENTVSYNC);
			if (sdlRenderer) {

				// NOTE(khvorov) SDL by default does not send mouse clicks when clicking on an unfocused window
				{
					i32 clickthrough = 1;
					SDL_SetHint(SDL_HINT_MOUSE_FOCUS_CLICKTHROUGH, (const char*)&clickthrough);
				}

				Input input = {0};
				input.cursorX = -1;
				input.cursorY = -1;

				UI ui = {0};
				uiInit(&ui);

				b32 running = true;
				while (running) {

					clearHalfTransitionCounts(&input);

					SDL_Event event;
					SDL_WaitEvent(&event);
					processEvent(sdlWindow, &event, &running, &input);
					pollEvents(sdlWindow, &running, &input);

					SDL_SetRenderDrawColor(sdlRenderer, 20, 20, 20, 255);
					SDL_RenderClear(sdlRenderer);

					for (UIWindowID winID = 0; winID < UIWindowID_Count; winID++) {
						uiWindowUpdate(&ui, winID, &input);
					}

					for (i32 winOrderIndex = 0; winOrderIndex < UIWindowID_Count; winOrderIndex++) {
						UIWindowID winID = ui.windowOrder[winOrderIndex];
						drawRect(sdlRenderer, ui.windows[winID].rect, ui.windows[winID].color);
					}

					SDL_RenderPresent(sdlRenderer);
				}
			}
		}
	}

	return 0;
}
