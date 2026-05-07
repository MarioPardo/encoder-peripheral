

#include <stdio.h>                                                                 
#include <stdint.h>
#include <fcntl.h>                                                                 
#include <sys/mman.h>                                                              
#include <unistd.h>
                                                                                    
#define MAP_SIZE    0x10 //4 registers, 4 bytes each = 16 bytes = 0x10
#define CTRL_ENABLE (1 << 0)                                                       
#define CTRL_CLR    (1 << 1)                                                       

int main(void) 
{                                                                   
    int fd = open("/dev/uio0", O_RDWR | O_SYNC);
    if(fd < 0){perror("Failed to open /dev/uio0");return 1;}

    volatile uint32_t *enc = mmap(NULL, MAP_SIZE,PROT_READ | PROT_WRITE,MAP_SHARED, fd, 0);
    if(enc == MAP_FAILED){perror("Failed to mmap");close(fd);return 1;} 

    enc[0] = CTRL_CLR;                                                             
    enc[0] = CTRL_ENABLE;                                                          

    for (int i = 0; i < 30; i++) 
    {                                                 
        int32_t pos = (int32_t)enc[2];
        int32_t vel = (int32_t)enc[3];                                             
        uint32_t dir = enc[1] & 0x1;                                               
        printf("pos=%6d  vel=%6d  dir=%s\n", pos, vel, dir ? "FWD" : "REV");       
        sleep(1);                                                                  
    }           
                                                                                    
    munmap((void*)enc, MAP_SIZE);                                                  
    close(fd);
    return 0;                                                                      
}