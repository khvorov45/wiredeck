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

typedef enum Direction {
	Direction_Top,
	Direction_Right,
	Direction_Bottom,
	Direction_Left,
	Direction_Count,
} Direction;

typedef enum UIWindowID {
	UIWindowID_Root = -1,
	UIWindowID_1,
	UIWindowID_2,
	UIWindowID_Count,
} UIWindowID;

typedef enum DockPos {
	DockPos_Center,
	DockPos_Count,
} DockPos;

typedef struct UIWindow {
	SDL_Rect rect;
	SDL_Color color;

	b32 isDragged;
	i32 dragOffsetFromTopleftX;
	i32 dragOffsetFromTopleftY;

	b32 isDocked;
	DockPos dockPos;
	UIWindowID dockParent;
} UIWindow;

typedef struct UI {
	i32 width, height;
	i32 windowTopBarHeight;
	i32 windowBorderThickness;
	UIWindowID windowOrder[UIWindowID_Count]; // NOTE(khvorov) First window is drawn last (on top)
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

	ui->windowTopBarHeight = 20;
	ui->windowBorderThickness = 2;
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

SDL_Rect
rectCenterDim(i32 centerX, i32 centerY, i32 dimX, i32 dimY) {
	SDL_Rect result = {.x = centerX - dimX / 2, .y = centerY - dimY / 2, .w = dimX, .h = dimY};
	return result;
}

SDL_Rect
rectShrink(SDL_Rect rect, i32 by) {
	SDL_Rect result = rect;
	result.x += by;
	result.y += by;
	result.w -= 2 * by;
	result.h -= 2 * by;
	return result;
}

void
getOutlineRects(SDL_Rect rect, SDL_Rect* rects, i32 thickness) {
	SDL_Rect top = rect;
	top.h = thickness;

	SDL_Rect bottom = top;
	bottom.y += rect.h - thickness;

	SDL_Rect right = rect;
	right.w = thickness;

	SDL_Rect left = right;
	left.x += rect.w - thickness;

	rects[Direction_Top] = top;
	rects[Direction_Bottom] = bottom;
	rects[Direction_Right] = right;
	rects[Direction_Left] = left;
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
uiGetRootDockRects(UI* ui, SDL_Rect* rects) {
	rects[DockPos_Center] = rectCenterDim(ui->width / 2, ui->height / 2, 100, 100);
}

void
uiMoveWindowToFront(UI* ui, UIWindowID winID) {
	i32 winOrderIndex = 0;
	for (; winOrderIndex < UIWindowID_Count; winOrderIndex++) {
		if (ui->windowOrder[winOrderIndex] == winID) {
			break;
		}
	}

	if (winOrderIndex < UIWindowID_Count) {
		for (; winOrderIndex > 0; winOrderIndex--) {
			ui->windowOrder[winOrderIndex] = ui->windowOrder[winOrderIndex - 1];
			ui->windowOrder[winOrderIndex - 1] = winID;
		}
	}
}

SDL_Rect
uiGetWindowRect(UI* ui, UIWindowID winID) {
	SDL_Rect winRect = {.x = 0, .y = 0, .w = ui->width, .h = ui->height};
	if (winID >= 0 && winID < UIWindowID_Count) {
		UIWindow* win = ui->windows + winID;
		winRect = win->rect;
		if (win->isDocked) {
			SDL_Rect parentRect = uiGetWindowRect(ui, win->dockParent);

			switch (win->dockPos) {
			case DockPos_Center: {winRect = parentRect;} break;
			}
		}
	}
	return winRect;
}

SDL_Rect
uiGetWindowTopbarRect(UI* ui, UIWindowID winID) {
	SDL_Rect winRect = uiGetWindowRect(ui, winID);
	SDL_Rect topBarRect = rectShrink(winRect, ui->windowBorderThickness);
	topBarRect.h = ui->windowTopBarHeight;
	return topBarRect;
}

SDL_Rect
uiGetWindowContentRect(UI* ui, UIWindowID winID) {
	SDL_Rect winRect = uiGetWindowRect(ui, winID);
	SDL_Rect contentRect = rectShrink(winRect, ui->windowBorderThickness);
	contentRect.h -= ui->windowTopBarHeight;
	contentRect.y += ui->windowTopBarHeight;
	return contentRect;
}

void
uiWindowUpdate(UI* ui, UIWindowID winID, Input* input) {

	UIWindow* win = ui->windows + winID;
	SDL_Rect winRect = uiGetWindowRect(ui, winID);

	if (wasPressed(input, InputKeyID_MouseLeft)) {

		if (pointInRect(input->cursorX, input->cursorY, winRect)) {
			uiMoveWindowToFront(ui, winID);
			input->keys[InputKeyID_MouseLeft].halfTransitionCount = 0;
		}

		// NOTE(khvorov) Dragging
		SDL_Rect windowTopbarRect = uiGetWindowTopbarRect(ui, winID);
		if (pointInRect(input->cursorX, input->cursorY, windowTopbarRect)) {

			if (win->isDocked) {
				win->isDocked = false;
				win->dockPos = 0;
				win->dockParent = 0;

				f32 clickX01 = (f32)(input->cursorX - winRect.x) / (f32)windowTopbarRect.w;
				i32 clickYOffset = input->cursorY - winRect.y;

				SDL_Rect newTopBar = uiGetWindowTopbarRect(ui, winID);
				win->rect.x = input->cursorX - ui->windowBorderThickness - (i32)(clickX01 * (f32)newTopBar.w);
				win->rect.y = input->cursorY - clickYOffset;
			}

			win->isDragged = true;
			win->dragOffsetFromTopleftX = input->cursorX - win->rect.x;
			win->dragOffsetFromTopleftY = input->cursorY - win->rect.y;
			win->color.b = 255;
		}

	} else if (wasUnpressed(input, InputKeyID_MouseLeft) && win->isDragged) {

		SDL_Rect rootDockRects[DockPos_Count];
		uiGetRootDockRects(ui, rootDockRects);
		for (DockPos pos = 0; pos < DockPos_Count; pos++) {
			SDL_Rect rect = rootDockRects[pos];
			if (pointInRect(input->cursorX, input->cursorY, rect)) {
				win->isDocked = true;
				win->dockPos = pos;
				win->dockParent = UIWindowID_Root;
			}
		}

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
drawRectOutline(SDL_Renderer* sdlRenderer, SDL_Rect rect, SDL_Color color, i32 thickness) {
	SDL_Rect outlineRects[Direction_Count];
	getOutlineRects(rect, outlineRects, thickness);
	for (Direction dir = 0; dir < Direction_Count; dir++) {
		SDL_Rect outlineRect = outlineRects[dir];
		drawRect(sdlRenderer, outlineRect, color);
	}
}

void
drawWindow(SDL_Renderer* sdlRenderer, UI* ui, UIWindowID winID) {
	UIWindow* win = ui->windows + winID;

	SDL_Rect winRect = uiGetWindowRect(ui, winID);
	SDL_Color windowOutlineColor = {.r = 100, .g = 100, .b = 100, .a = 255};
	drawRectOutline(sdlRenderer, winRect, windowOutlineColor, ui->windowBorderThickness);

	SDL_Rect topBarRect = uiGetWindowTopbarRect(ui, winID);
	drawRect(sdlRenderer, topBarRect, win->color);

	SDL_Rect contentRect = uiGetWindowContentRect(ui, winID);
	SDL_Color contentRectBGColor = {.r = 0, .g = 0, .b = 0, .a = 255};
	drawRect(sdlRenderer, contentRect, contentRectBGColor);
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

					{
						SDL_Rect viewport;
						SDL_RenderGetViewport(sdlRenderer, &viewport);
						ui.width = viewport.w;
						ui.height = viewport.h;
					}

					SDL_SetRenderDrawColor(sdlRenderer, 20, 20, 20, 255);
					SDL_RenderClear(sdlRenderer);

					{
						UIWindowID windowOrder[UIWindowID_Count];
						for (i32 winOrderIndex = 0; winOrderIndex < UIWindowID_Count; winOrderIndex++) {
							windowOrder[winOrderIndex] = ui.windowOrder[winOrderIndex];
						}

						for (i32 winOrderIndex = 0; winOrderIndex < UIWindowID_Count; winOrderIndex++) {
							UIWindowID winID = windowOrder[winOrderIndex];
							uiWindowUpdate(&ui, winID, &input);
						}
					}

					for (i32 winOrderIndex = UIWindowID_Count - 1; winOrderIndex >= 0; winOrderIndex--) {
						UIWindowID winID = ui.windowOrder[winOrderIndex];
						drawWindow(sdlRenderer, &ui, winID);
					}

					SDL_Color dockRectColor = {.r = 0, .g = 0, .b = 255, .a = 255};
					SDL_Rect rootDockRects[DockPos_Count];
					uiGetRootDockRects(&ui, rootDockRects);
					for (DockPos pos = 0; pos < DockPos_Count; pos++) {
						SDL_Rect rect = rootDockRects[pos];
						drawRect(sdlRenderer, rect, dockRectColor);
					}

					SDL_RenderPresent(sdlRenderer);
				}
			}
		}
	}

	return 0;
}
