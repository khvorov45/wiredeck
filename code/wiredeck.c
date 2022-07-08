#include <stdint.h>
#include "SDL/include/SDL.h"
#include "microui.c"

#define true 1
#define false 0
#define function static

typedef uint8_t u8;
typedef int32_t b32;
typedef int32_t i32;
typedef float f32;

function i32
getTextWidth(mu_Font font, const char *text, int len) {
	if (len == -1) {
		len = SDL_strlen(text);
	}
	i32 result = len * 20;
	return result;
}

function i32
getTextHeight(mu_Font font) {
	i32 result = 20;
	return result;
}

function void
updateUI(mu_Context* ui) {
	mu_begin(ui);

	if (mu_begin_window(ui, "Placeholder", mu_rect(350, 250, 300, 240))) {
		mu_end_window(ui);
	}

	mu_end(ui);
}

function i32
muButtonFromSdlButton(i32 sdlButton) {
	i32 result = -1;
	switch (sdlButton) {
	case SDL_BUTTON_LEFT: result = MU_MOUSE_LEFT; break;
	case SDL_BUTTON_RIGHT: result = MU_MOUSE_RIGHT; break;
	case SDL_BUTTON_MIDDLE: result = MU_MOUSE_MIDDLE; break;
	}
	return result;
}

int
SDL_main(int argc, char* argv[]) {
	if (SDL_Init(SDL_INIT_VIDEO) == 0) {

		// NOTE(khvorov) I would like to clear the window before it shows up
		// at all but I haven't found a way to do that on Windows and have
		// the window work as expected.
		SDL_Window* window = SDL_CreateWindow("wiredeck", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 1000, 1000, 0);
		if (window) {

			SDL_Renderer* sdlRenderer = SDL_CreateRenderer(window, -1, 0);
			if (sdlRenderer) {

				// NOTE(khvorov) SDL by default does not send mouse clicks when clicking on an unfocused window
				{
					i32 clickthrough = 1;
					SDL_SetHint(SDL_HINT_MOUSE_FOCUS_CLICKTHROUGH, (u8*)&clickthrough);
				}

				mu_Context* ui = SDL_malloc(sizeof(mu_Context));
				mu_init(ui);
				ui->text_width = getTextWidth;
				ui->text_height = getTextHeight;

				b32 running = true;
				while (running) {

					SDL_Event event;
					if (SDL_WaitEvent(&event)) {

						switch (event.type) {
						case SDL_QUIT: running = false; break;
				        case SDL_MOUSEMOTION: mu_input_mousemove(ui, event.motion.x, event.motion.y); break;
				        case SDL_MOUSEBUTTONDOWN: mu_input_mousedown(ui, event.button.x, event.button.y, muButtonFromSdlButton(event.button.button)); break;
				        case SDL_MOUSEBUTTONUP: mu_input_mouseup(ui, event.button.x, event.button.y, muButtonFromSdlButton(event.button.button)); break;
						}

						updateUI(ui);

						SDL_SetRenderDrawColor(sdlRenderer, 0, 0, 0, 0);
						SDL_RenderClear(sdlRenderer);

						mu_Command* cmd = 0;
						while (mu_next_command(ui, &cmd)) {

							switch (cmd->type) {
							case MU_COMMAND_RECT: {

								mu_Color muColor = cmd->rect.color;
								SDL_SetRenderDrawColor(sdlRenderer, muColor.r, muColor.g, muColor.b, muColor.a);

								mu_Rect muRect = cmd->rect.rect;
								SDL_Rect sdlRect = {.x = muRect.x, .y = muRect.y, .w = muRect.w, .h = muRect.h};
								SDL_RenderFillRect(sdlRenderer, &sdlRect);
							} break;
							}
						}

						SDL_RenderPresent(sdlRenderer);
					} else {
						running = false;
					}
				}
			}
		}
	}

	return 0;
}
