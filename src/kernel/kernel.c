#include "kernel.h"

void kernel_main()
{
    char* video_memory = (char*) 0xB8000;
    video_memory[0] = 'O';
    video_memory[1] = 0x0F; // Light gray on black
    video_memory[2] = 'K';
    video_memory[3] = 0x0F;
}
