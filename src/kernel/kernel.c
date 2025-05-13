#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include "kernel.h"

#define VGA_WIDTH   80
#define VGA_HEIGHT  25
#define VGA_MEMORY  0xB8000

typedef enum
{
	VGA_COLOR_BLACK = 0,
	VGA_COLOR_BLUE = 1,
	VGA_COLOR_GREEN = 2,
	VGA_COLOR_CYAN = 3,
	VGA_COLOR_RED = 4,
	VGA_COLOR_MAGENTA = 5,
	VGA_COLOR_BROWN = 6,
	VGA_COLOR_LIGHT_GREY = 7,
	VGA_COLOR_DARK_GREY = 8,
	VGA_COLOR_LIGHT_BLUE = 9,
	VGA_COLOR_LIGHT_GREEN = 10,
	VGA_COLOR_LIGHT_CYAN = 11,
	VGA_COLOR_LIGHT_RED = 12,
	VGA_COLOR_LIGHT_MAGENTA = 13,
	VGA_COLOR_LIGHT_BROWN = 14,
	VGA_COLOR_WHITE = 15,
} vga_color_t;

static inline uint8_t vga_entry_color(vga_color_t fg, vga_color_t bg)
{
    return fg | bg << 4;
}

static inline uint16_t vga_entry(unsigned char uc, uint8_t color) 
{
	return (uint16_t) uc | (uint16_t) color << 8;
}

typedef struct
{
    size_t row;
    size_t col;
    uint8_t color;
    uint16_t *buffer;
} terminal_t;

terminal_t create_terminal()
{
    terminal_t terminal = {};
    terminal.row = 0;
    terminal.col = 0;
    terminal.color = vga_entry(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK);
    terminal.buffer = (uint16_t*)VGA_MEMORY;

    for (size_t y = 0; y < VGA_HEIGHT; y++)
    {
        for (size_t x = 0; x < VGA_WIDTH; x++)
        {
            terminal.buffer[y * VGA_WIDTH + x] = vga_entry(' ', terminal.color);
        }
    }

    return terminal;
}

void put_c(terminal_t *terminal, char c)
{
    terminal->buffer[terminal->col * VGA_WIDTH + terminal->row] = vga_entry(c, terminal->color);
    if (terminal->col++ >= VGA_WIDTH)
    {
        terminal->col = 0;
        if (terminal->row++ >= VGA_HEIGHT)
            terminal->row = 0;
    }
}

void kernel_main()
{
    terminal_t terminal = create_terminal();
    put_c(&terminal, 'O');
    put_c(&terminal, 'K');
}
