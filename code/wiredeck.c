#include "SDL/include/SDL.h"

void
wiredeckMain() {
	if (SDL_Init(SDL_INIT_VIDEO) == 0) {
		SDL_Window* window = SDL_CreateWindow("wiredeck", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 1000, 1000, 0);
		SDL_Renderer* renderer = SDL_CreateRenderer(window, -1, 0);

		SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0);
		SDL_RenderClear(renderer);
		SDL_RenderFlush(renderer);
	    SDL_UpdateWindowSurface(window);

		SDL_Event event;
		while (SDL_WaitEvent(&event)) {

		    SDL_UpdateWindowSurface(window);
		}
	}
}

#if PLATFORM_WINDOWS

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

int
WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nShowCmd) {
	wiredeckMain();
	return 0;
}

#endif
