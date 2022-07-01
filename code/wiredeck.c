#include <windows.h>
#include "SDL/include/SDL.h"

int
WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nShowCmd) {
	SDL_Init(SDL_INIT_VIDEO);
	return 0;
}
