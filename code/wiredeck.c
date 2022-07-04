#include <stdint.h>
#include "SDL/include/SDL.h"

#define true 1
#define false 0

typedef uint8_t u8;
typedef int32_t b32;
typedef int32_t i32;
typedef float f32;

typedef struct Input {
	i32 temp_;
} Input;

typedef struct Renderer {
	SDL_Renderer* sdl_renderer;
} Renderer;

typedef struct Rect {
	i32 l, r, t, b;
} Rect;

typedef struct Color255 {
	u8 r, g, b, a;
} Color255;

void
drawRect(Renderer renderer, Rect rect, Color255 color) {
	SDL_Rect sdl_rect = {.x = rect.l, .y = rect.t, .w = rect.r - rect.l, .h = rect.b - rect.t};
	SDL_SetRenderDrawColor(renderer.sdl_renderer, color.r, color.g, color.b, color.a);
	SDL_RenderFillRect(renderer.sdl_renderer, &sdl_rect);
}

void
updateAndRender(Renderer renderer, Input input) {
	Rect rect = {.l = 10, .t = 10, .r = 100, .b = 100};
	Color255 color = {.r = 100, .g = 0, .b = 0, .a = 255};
	drawRect(renderer, rect, color);
}

int
SDL_main(int argc, char* argv[]) {
	if (SDL_Init(SDL_INIT_VIDEO) == 0) {

		// NOTE(khvorov) I would like to clear the window before it shows up
		// at all but I haven't found a way to do that on Windows and have
		// the window work as expected.
		SDL_Window* window = SDL_CreateWindow("wiredeck", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 1000, 1000, 0);
		if (window) {

			SDL_Renderer* sdl_renderer = SDL_CreateRenderer(window, -1, 0);
			if (sdl_renderer) {

				Renderer renderer = {.sdl_renderer = sdl_renderer};
				Input input = {0};

				b32 running = true;
				while (running) {

					SDL_Event event;
					if (SDL_WaitEvent(&event)) {

						switch (event.type) {
						case SDL_QUIT: {
							running = false;
						} break;
						}

						SDL_SetRenderDrawColor(sdl_renderer, 0, 0, 0, 0);
						SDL_RenderClear(sdl_renderer);
						updateAndRender(renderer, input);
						SDL_RenderPresent(sdl_renderer);
					} else {
						running = false;
					}
				}
			}
		}
	}

	return 0;
}
