//
//#include <stdio.h>
//#include <stdlib.h>
//#include <sys/types.h>
//#include <sys/stat.h>
//#include <fcntl.h>
//#include <string.h>
//#include <sys/time.h>
//
//
//#include "ff.h"
//
//#include "diskio.h"
//
//FATFS* fs = NULL;
//FIL* fp = NULL;
//
//struct timeval	tv1, tv2;
//
//
//char *rbuff = NULL;
//#define RBUF_LEN (1*1024) //512*1024
//#define TOTAL_LEN (104857600) //100*1024*1024
//#define RBUFF_CNT  400000
//FSIZE_t pos;
//
//int main(char argc, char **argv)
//{
//	int i;
//	UINT readlen, writelen;
//	FRESULT ret;
//	//printf("argc=%d  argv[0]=%s  argv[1]=%s\n", argc, argv[0], argv[1]);
//
//	fs = malloc(sizeof(FATFS));
//	fp = malloc(sizeof(FIL));
//	
//	rbuff = malloc(RBUF_LEN); //
//	
//	if(fs == NULL || fp == NULL || rbuff == NULL)
//	{
//		printf("alloc mem for fs/fp/rbuff failed!\n");
//		exit(1);
//	}
//
//	memset(fs, 0, sizeof(FATFS));
//	memset(fp, 0, sizeof(FIL));
//	//memset(rbuff, 0, RBUF_LEN);
//
//	if(FR_OK != f_mount(fs, "0:", 1))
//	{
//		printf("mount failed!\n");
//		exit(1);
//	}
//	printf("mount succes!\n");
//
//	ret = f_open(fp, "/hu.txt", FA_READ|FA_WRITE);
//	if(FR_OK != ret)
//	{
//		printf("open failed, ret=%d!\n", ret);
//		exit(1);
//	}
//	printf("open succes!\n");
//
//	if(FR_OK != f_lseek(fp, 0))
//	{
//		printf("lseek failed!\n");
//		exit(1);
//	}
//
//	for(i=0; i<RBUFF_CNT; i++)
//	{
//		gettimeofday(&tv1, NULL);
//		ret = f_write(fp, rbuff, RBUF_LEN, &writelen);
//		gettimeofday(&tv2, NULL);
//		if(FR_OK != ret)
//		{
//			printf("write failed, ret=%d  i=%d!\n", ret, i);
//			exit(1);
//		}
//
//		if(i==1 || i==(RBUFF_CNT-1))
//		{
//			printf("start %d.%d\n", tv1.tv_sec, tv1.tv_usec);
//			printf("end   %d.%d\n\n", tv2.tv_sec, tv2.tv_usec);
//		}
//	}
//	
//	printf("write line=%d!\n", i);
//	
//	f_close(fp);
//
//	free(fp);
//	free(fs);
//	
//	return 0;
//}
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
