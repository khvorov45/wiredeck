#include <stdint.h>
#include "SDL.h"
#include "imgui.cpp"
#include "imgui_widgets.cpp"
#include "imgui_draw.cpp"
#include "imgui_demo.cpp"
#include "imgui_tables.cpp"
#include "imgui_impl_sdl.cpp"
#include "imgui_impl_sdlrenderer.cpp"

#define true 1
#define false 0
#define function static

typedef uint8_t u8;
typedef int32_t b32;
typedef int32_t i32;
typedef float f32;

void
processEvent(SDL_Window* window, SDL_Event* event, i32* eventCount, b32* running) {
    ImGui_ImplSDL2_ProcessEvent(event);
	if (event->type == SDL_QUIT) {
		*running = false;
	}
	if (event->type == SDL_WINDOWEVENT && event->window.event == SDL_WINDOWEVENT_CLOSE && event->window.windowID == SDL_GetWindowID(window)) {
		*running = false;
	}
	(*eventCount)++;
}

void
pollEvents(SDL_Window* window, i32* eventCount, b32* running) {
	SDL_Event event;
	while (SDL_PollEvent(&event)) {
		processEvent(window, &event, eventCount, running);
	}
}

int
SDL_main(int argc, char* argv[]) {
	if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER) == 0) {

		// NOTE(khvorov) I would like to clear the window before it shows up
		// at all but I haven't found a way to do that on Windows and have
		// the window work as expected.
		SDL_Window* sdlWindow = SDL_CreateWindow("wiredeck", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 1000, 1000, 0);
		if (sdlWindow) {

			SDL_Renderer* sdlRenderer = SDL_CreateRenderer(sdlWindow, -1, SDL_RENDERER_PRESENTVSYNC);
			if (sdlRenderer) {

				// NOTE(khvorov) SDL by default does not send mouse clicks when clicking on an unfocused window
				{
					i32 clickthrough = 1;
					SDL_SetHint(SDL_HINT_MOUSE_FOCUS_CLICKTHROUGH, (const char*)&clickthrough);
				}

				IMGUI_CHECKVERSION();
				ImGui::CreateContext();
				ImGuiIO& io = ImGui::GetIO(); (void)io;

				ImGui::StyleColorsDark();

				ImGui_ImplSDL2_InitForSDLRenderer(sdlWindow, sdlRenderer);
				ImGui_ImplSDLRenderer_Init(sdlRenderer);

				b32 running = true;
				i32 framesDrawnWithoutEvents = 0;
				while (running) {

					i32 eventCount = 0;
					SDL_Event event;

					// NOTE(khvorov) Dear ImGUI will fail to correctly draw everything on every frame if the element it
					// draws appears after an input that changed it. So have to draw extra frames while idle.
					i32 framesToDrawWithoutEvents = 2;

					if (framesDrawnWithoutEvents < framesToDrawWithoutEvents) {
						pollEvents(sdlWindow, &eventCount, &running);
					} else {
						framesDrawnWithoutEvents = 0;
						SDL_WaitEvent(&event);
						processEvent(sdlWindow, &event, &eventCount, &running);
						pollEvents(sdlWindow, &eventCount, &running);
					}

					if (eventCount == 0) framesDrawnWithoutEvents++;

					ImGui_ImplSDLRenderer_NewFrame();
					ImGui_ImplSDL2_NewFrame();
					ImGui::NewFrame();

					ImGui::ShowDemoWindow(0);

					ImGui::Render();

					SDL_SetRenderDrawColor(sdlRenderer, 20, 20, 20, 255);
					SDL_RenderClear(sdlRenderer);
					ImGui_ImplSDLRenderer_RenderDrawData(ImGui::GetDrawData());
					SDL_RenderPresent(sdlRenderer);
				}
			}
		}
	}

	return 0;
}
