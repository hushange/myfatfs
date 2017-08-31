/*
 Authors: huyongfa(hushange@163.com)
 
 
 Changes:
 
 
 */

#include "diskio.h"
#import "LGGeneralFs.h"
#include "ff.h"
#include "../gobal.h"
#include "./lfs_protocol/l_fs_protocol.h"

unsigned long long g_capacity = 0;

#define  COMPILE_MY_SCHEDULER   1
#define  USE_MY_SCHEDULER       1
#define  RINFO_BUFF_SECTOR      64
#define  FAT_EXTEND_SECTOR      1000
#define  WINFO_BUFF_SECTOR      40960

#if COMPILE_MY_SCHEDULER
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

struct readinfo
{
    UINT  dirty;
    DWORD lba;
    UINT  cnt;
    BYTE *buff;
    UINT  isready;
}rinfo;

struct fat_info
{
    UINT  dirty;
    UINT  isready;
    DWORD fbase;
    DWORD dbase;
    DWORD dbasext;
    DWORD lba;
    UINT  cnt;
    BYTE  *buff;
    UINT  bufsec;
}fatinfo;

struct writeinfo
{
    UINT  dirty;
    UINT  isready;
    DWORD lba;
    UINT  cnt;
    BYTE  *buff;
    UINT  bufsec;
    WORD  csize;
}winfo;

UINT isready = 0;

DRESULT my_diskread(BYTE *buff, DWORD sector, UINT count);

void dgb(char *str, DWORD lba, UINT cnt, int res)
{
    ; //[[LGGeneralFs GetSharedLGGeneralInstance] writeMsg:[NSString stringWithFormat:@"%s  lba=%lu   cnt=%d  res=%d", str, lba, cnt, res]];
}

void myset_fs_info(DWORD fbase, DWORD dbase, WORD csize)
{
    if(0 < fbase && fbase < dbase)
    {
        fatinfo.fbase = fbase;
        fatinfo.dbase = dbase;
        fatinfo.dbasext = dbase + FAT_EXTEND_SECTOR;
        fatinfo.bufsec = dbase - fbase + FAT_EXTEND_SECTOR;
        if(fatinfo.buff == 0)
            fatinfo.buff = malloc(fatinfo.bufsec*512);
        
        dgb("myset_fs_info read fattab", fatinfo.fbase, fatinfo.bufsec, 0);
        my_diskread(fatinfo.buff, fatinfo.fbase, fatinfo.bufsec);
        fatinfo.lba = fatinfo.fbase;
        fatinfo.cnt = fatinfo.bufsec;
        fatinfo.isready = 1;
        
        winfo.dirty = 0;
        winfo.lba = 0;
        winfo.cnt = 0;
        winfo.csize = csize;
        winfo.bufsec = WINFO_BUFF_SECTOR;
        if(winfo.buff == 0)
            winfo.buff = malloc(winfo.bufsec*512);
        winfo.isready = 0;// winfo has some issues, such as can't re-load pictures after rm dir
        
        rinfo.lba = 0;
        rinfo.cnt = 0;
        if(rinfo.buff == 0)
            rinfo.buff = malloc(RINFO_BUFF_SECTOR*512);
        rinfo.isready = 1;
        
        isready = 1;
    }
    else
    {
        //if(fatinfo.buff)
        //    free(fatinfo.buff);
        fatinfo.fbase = 0;
        fatinfo.dbasext = 0;
        fatinfo.bufsec =0;
        fatinfo.buff = 0;
        fatinfo.isready = 0;
        fatinfo.lba = 0;
        fatinfo.cnt = 0;
        fatinfo.dirty = 0;
        
        winfo.isready = 0;
        //if(winfo.buff)
        //    free(winfo.buff);
        winfo.dirty = 0;
        winfo.lba = 0;
        winfo.cnt = 0;
        winfo.bufsec = 0;
        winfo.buff = 0;
        winfo.csize = 0;
        
        rinfo.isready = 0;
        rinfo.lba = 0;
        rinfo.cnt = 0;
        //if(rinfo.buff)
        //    free(rinfo.buff);
        
        isready = 0;
    }
    
    //printf("myset_fs_info: %s fatinfo,  fbase = %d   dbase = %d!\n",
    //        fatinfo.isready ==0 ? "disable":"enable", fatinfo.fbase, fatinfo.dbasext);
}

DRESULT my_diskopen()
{
    DRESULT res = RES_OK;
    [real_l_lib GetDiskCapacity];
    //    if(NULL == rinfo.buff)
    //    {
    //        rinfo.buff = malloc(RINFO_BUFF_SECTOR*512);
    //        if(0 != rinfo.buff)
    //        {
    //            rinfo.lba = 0;
    //            rinfo.cnt = 0;
    //            rinfo.dirty = 0;
    //        }
    //        else
    //        {
    //            res = RES_ERROR;
    //        }
    //    }
    
    return res;
}

void my_diskclose(void)
{
    //    rinfo.buff = NULL;
    //    rinfo.lba = 0;
    //    rinfo.cnt = 0;
    //    rinfo.dirty = 0;
}

DRESULT my_diskread(BYTE *buff, DWORD sector, UINT count)
{
    DRESULT res = RES_OK;
    //pthread_mutex_lock(&mutex);
    res = [real_l_lib ReadDisk:sector length:count buffer:buff];
    //[[LGGeneralFs GetSharedLGGeneralInstance] writeMsg:[NSString stringWithFormat:@"my_diskread   lba=%lu   cnt=%d  res=%d\n", sector, count, res]];
    dgb("my_diskread", sector, count, res);
    //pthread_mutex_unlock(&mutex);
    return res;
}

DRESULT my_diskwrite(BYTE *buff, DWORD sector, UINT count)
{
    DRESULT res = RES_OK;
    //pthread_mutex_lock(&mutex);
    res = [real_l_lib WriteDisk:sector length:count buffer:(uint8_t *)buff];
    dgb("my_diskwrite", sector, count, res);
    //pthread_mutex_unlock(&mutex);
    return res;
}

void my_winfo_sync(void)
{
    DRESULT res = RES_OK;
    
    pthread_mutex_lock(&mutex);
    
    if(fatinfo.dirty)
    {
        dgb("sync fatinfo", fatinfo.lba, fatinfo.cnt, 0);
        res = [real_l_lib WriteDisk:fatinfo.lba length:fatinfo.cnt buffer:(uint8_t *)fatinfo.buff];
    }
    fatinfo.dirty = 0;
    //fatinfo.lba = 0;
    //fatinfo.cnt = 0;
    
    
    if(winfo.dirty)
    {
        dgb("sync winfo", winfo.lba, winfo.cnt, 0);
        res = [real_l_lib WriteDisk:winfo.lba length:winfo.cnt buffer:(uint8_t *)winfo.buff];
    }
    winfo.dirty = 0;
    winfo.lba = 0;
    winfo.cnt = 0;
    
    rinfo.lba = 0;
    rinfo.cnt = 0;
    
    pthread_mutex_unlock(&mutex);
}

void my_fatinfo_sync2(void)
{
    DRESULT res = RES_OK;
    
    if(fatinfo.dirty)
    {
        //pthread_mutex_lock(&mutex);
        dgb("sync fatinfo2", fatinfo.lba, fatinfo.cnt, 0);
        res = [real_l_lib WriteDisk:fatinfo.lba length:fatinfo.cnt buffer:(uint8_t *)fatinfo.buff];
        //pthread_mutex_unlock(&mutex);
    }
    fatinfo.dirty = 0;
}

void my_winfo_sync2(void)
{
    DRESULT res = RES_OK;
    
    if(winfo.dirty)
    {
        //pthread_mutex_lock(&mutex);
        dgb("sync winfo2", winfo.lba, winfo.cnt, 0);
        res = [real_l_lib WriteDisk:winfo.lba length:winfo.cnt buffer:(uint8_t *)winfo.buff];
        //pthread_mutex_unlock(&mutex);
        winfo.cnt = 0;
        winfo.lba   = 0;
    }
    winfo.dirty = 0;
}


DRESULT my_scheduler(BYTE *buff, DWORD sector, UINT count, UINT iswrite)
{
    DRESULT res = RES_OK;
    DWORD offset, curlba, nextcluserlba = 0;
    UINT len = 0;
    UINT needwrite = 0, needread = 0;
    //[real_l_lib openMsg:sector setaaa:buff];
    dgb("my_schedule():", sector, count, iswrite);
    if(iswrite)
    {
#if USE_MY_SCHEDULER
        
        if(isready)
        {
            if(fatinfo.fbase <= sector && sector < fatinfo.dbasext)
            {
                if(fatinfo.isready && fatinfo.cnt)
                {
                    if(fatinfo.lba <= sector
                       && ((sector+count) <= (fatinfo.lba+fatinfo.cnt)))
                    {
                        offset = (sector - fatinfo.lba)*512;
                        len    = count * 512;
                        memcpy(fatinfo.buff + offset, buff, len);
                        dgb("schedule w fresh fatinfo by sector", sector, count, 0);
                        //printf("my_scheduler fresh fatinfo: offset=%d  info.lba=%d  info.count=%d  lba=%d  count=%d\n",
                        //     offset, fatinfo.lba, fatinfo.cnt, sector, count);
                        needwrite = 0;
                        fatinfo.dirty = 1;
                    }
                    else
                    {
                        dgb("schedule w sync and re-read fatinfo by sector", sector, count, 0);
                        my_fatinfo_sync2();
                        my_diskwrite(buff, sector, count);
                        my_diskread(fatinfo.buff, fatinfo.fbase, fatinfo.bufsec);
                        fatinfo.lba = fatinfo.fbase;
                        fatinfo.cnt = fatinfo.bufsec;
                    }
                }
                else
                {
                    dgb("schedule w fatinfo not ready", sector, count, 0);
                    my_diskwrite(buff, sector, count);
                }
            }
            else
            {
                if(rinfo.isready && rinfo.cnt > 0)
                {
                    if((sector+count) <= rinfo.lba
                       || (rinfo.lba+rinfo.cnt) <= sector)
                        ;
                    else if(rinfo.lba <= sector
                            && (sector+count) <= (rinfo.lba+rinfo.cnt))
                    {
                        //info    |--------------------|
                        //user      |-----------------|
                        offset = (sector - rinfo.lba)*512;
                        len    = count * 512;
                        memcpy(rinfo.buff + offset, buff, len);
                        dgb("schedule w fresh rinfo", rinfo.lba, rinfo.cnt, 0);
                        //printf("my_scheduler save diskcard write: offset=%d  info.lba=%d  info.count=%d  lba=%d  count=%d\n",
                        //     offset, rinfo.lba, rinfo.cnt, sector, count);
                    }
                    else
                    {
                        dgb("schedule w discard rinfo", rinfo.lba, rinfo.cnt, 0);
                        rinfo.dirty = 0;
                        rinfo.cnt = 0;
                        rinfo.lba = 0;
                    }
                }
                
                if(count >= winfo.csize  && winfo.isready)
                {
                    curlba = winfo.lba + winfo.cnt;
                    nextcluserlba = curlba + (winfo.csize - curlba%winfo.csize);
                    if(0 == winfo.cnt)
                    {
                        winfo.cnt = count;
                        winfo.lba = sector;
                        memcpy(winfo.buff, buff, count*512);
                        winfo.dirty = 1;
                        dgb("schedule w winfo init", winfo.lba, winfo.cnt, 0);
                        //printf("winfo match0  %d -- %d, cnt = %d\n", winfo.lba, sector+count, count);
                    }
                    else if(sector == curlba && (winfo.cnt + count) < winfo.bufsec)
                    {
                        offset = winfo.cnt * 512;
                        len    = count * 512;
                        winfo.cnt += count;
                        memcpy(winfo.buff + offset, buff, len);
                        winfo.dirty = 1;
                        dgb("schedule w winfo combind sector", winfo.lba, winfo.cnt, 0);
                        //printf("winfo match1  %d -- %d, cnt = %d\n", winfo.lba, curlba, winfo.cnt);
                    }
                    else if(sector == nextcluserlba && ((sector + count) - winfo.lba) < winfo.bufsec)
                    {
                        offset = (sector - winfo.lba)*512;
                        len    = count * 512;
                        winfo.cnt = (sector + count - winfo.lba);
                        memcpy(winfo.buff + offset, buff, len);
                        winfo.dirty = 1;
                        dgb("schedule w winfo combind cluser", winfo.lba, winfo.cnt, 0);
                        //printf("winfo match2  %d -- %d |---| %d -- %d, cnt= %d\n", winfo.lba, curlba, sector, sector+count, winfo.cnt);
                    }
                    else
                    {
                        //printf("winfo match3  %d -- %d, new %d -- %d\n", winfo.lba, curlba, sector, sector+count);
                        dgb("schedule w winfo discard by sector", sector, count, 0);
                        my_winfo_sync2();
#if 0
                        winfo.cnt = count;
                        winfo.lba = sector;
                        memcpy(winfo.buff, buff, count*512);
                        winfo.dirty = 1;
#else
                        winfo.cnt = 0;
                        winfo.lba = 0;
                        winfo.dirty = 0;
                        my_diskwrite(buff, sector, count);
#endif
                    }
                }
                else
                {
                    //dgb("schedule w winfo not ready", winfo.lba, winfo.cnt, 0);
                    my_diskwrite(buff, sector, count);
                }
            }
        }
        else
        {
            my_diskwrite(buff, sector, count);
        }
#else
        my_diskwrite(buff, sector, count);
#endif
    }
    else
    {
#if USE_MY_SCHEDULER
        if(isready)
        {
            if(fatinfo.fbase <= sector && sector < fatinfo.dbasext)
            {
                if(fatinfo.isready)
                {
                    if(0 == fatinfo.cnt && count <= fatinfo.bufsec && sector == fatinfo.fbase)
                    {
                        if(0 == my_diskread(fatinfo.buff, sector, fatinfo.bufsec))
                        {
                            fatinfo.cnt = fatinfo.bufsec;
                            fatinfo.lba = sector;
                            memcpy(buff, fatinfo.buff, count*512);
                            dgb("schedule r fatinfo init", fatinfo.lba, fatinfo.cnt, 0);
                            //printf("my_scheduler match0 fatinfo: lba=%d  count=%d\n", sector, fatinfo.bufsec);
                        }
                    }
                    else if(fatinfo.lba <= sector
                            && (sector + count) <= (fatinfo.lba + fatinfo.cnt))
                    {
                        offset = (sector - fatinfo.lba)*512;
                        memcpy(buff, fatinfo.buff + offset, count*512);
                        dgb("schedule r fatinfo match by sector", sector, count, 0);
                        //printf("my_scheduler match1 fatinfo: offset=%d  rinfo.buff=%x off=%x\n", offset, fatinfo.buff, fatinfo.buff+offset, count);
                        //printf("my_scheduler match1 fatinfo: lba=%d  count=%d\n", sector, count);
                    }else
                    {
                        dgb("schedule r fatinfo discard", fatinfo.lba, fatinfo.cnt, 0);
                        my_fatinfo_sync2();
                        fatinfo.cnt = 0;
                        fatinfo.lba = 0;
                        my_diskread(buff, sector, count);
                        //printf("my_scheduler match2 fatinfo: lba=%d  count=%d\n", sector, count);
                    }
                }
                else
                {
                    dgb("schedule r fatinfo not ready", sector, count, 0);
                    my_diskread(buff, sector, count);
                }
            }
            else
            {
                needread = 1;
                if(winfo.isready && winfo.cnt)
                {
                    curlba = winfo.lba + winfo.cnt;
                    if(((sector+count) <= winfo.lba) || (curlba <= sector))
                        ;// nothing
                    else if((winfo.lba <= sector) && ((sector+count) <= curlba))
                    {
                        needread = 0;
                        offset = (sector - winfo.lba) * 512;
                        len    = count * 512;
                        memcpy(buff, winfo.buff + offset, len);
                        dgb("schedule r winfo match by secotr", sector, count, 0);
                        return res;
                    }
                    else
                    {
                        dgb("schedule r winfo discard by secotr", sector, count, 0);
                        my_winfo_sync2();
                        winfo.lba = 0;
                        winfo.cnt = 0;
                    }
                }
                
                if(needread)
                {
                    if(rinfo.isready && count < RINFO_BUFF_SECTOR)
                    {
                        if(0 == rinfo.cnt)
                        {
                            res = my_diskread(rinfo.buff, sector, RINFO_BUFF_SECTOR);
                            rinfo.dirty = 0;
                            rinfo.cnt = RINFO_BUFF_SECTOR;
                            rinfo.lba = sector;
                            dgb("schedule r rinfo init", rinfo.lba, rinfo.cnt, res);
                            memcpy(buff, rinfo.buff, count*512);
                        }
                        else if(rinfo.lba <= sector
                                && (sector + count) <= (rinfo.lba + rinfo.cnt))
                        {
                            offset = (sector - rinfo.lba)*512;
                            memcpy(buff, rinfo.buff + offset, count*512);
                            dgb("schedule r rinfo match by sector", sector, count, res);
                        }
                        else
                        {
                            res = my_diskread(rinfo.buff, sector, RINFO_BUFF_SECTOR);
                            rinfo.dirty = 0;
                            rinfo.cnt = RINFO_BUFF_SECTOR;
                            rinfo.lba = sector;
                            dgb("schedule r rinfo init2", rinfo.lba, rinfo.cnt, res);
                            memcpy(buff, rinfo.buff, count*512);
                        }
                    }
                    else
                    {
                        res = my_diskread(buff, sector, count);
                        dgb("schedule r rinfo not ready", sector, count, 0);
                    }
                }
            }
        }
        else
            res = my_diskread(buff, sector, count);
#else
        res = my_diskread(buff, sector, count);
#endif
    }
    
    return res;
}


DSTATUS disk_status (BYTE pdrv)
{
    return 0;
}

DSTATUS disk_initialize (BYTE pdrv)
{
    if(RES_OK != my_diskopen())
    {
        return STA_NODISK;
    }
    
    g_capacity = [real_l_lib GetDiskCapacity];
    return 0;
}

DRESULT disk_read (BYTE pdrv, BYTE *buff, DWORD sector, UINT count)
{
    DRESULT res = RES_OK;
    pthread_mutex_lock(&mutex);
    res = my_scheduler(buff, sector, count, 0);
    pthread_mutex_unlock(&mutex);
    return res;
}

DRESULT disk_write (BYTE pdrv,  const BYTE *buff, DWORD sector, UINT count)
{
    DRESULT res = RES_OK;
    pthread_mutex_lock(&mutex);
    res = my_scheduler(buff, sector, count, 1);
    pthread_mutex_unlock(&mutex);
    return res;
}

DRESULT disk_ioctl (BYTE pdrv, BYTE cmd, void *buff )
{
    return [real_l_lib DiskIoctl:(BYTE)pdrv contrl:(BYTE)cmd buffer:(void*)buff];
}


#else

void my_winfo_sync(void)
{
    return ;
}

void myset_fs_info(DWORD fbase, DWORD dbase, WORD csize)
{
    return ;
}

DSTATUS disk_status (BYTE pdrv)
{
    return 0;
}

DSTATUS disk_initialize (BYTE pdrv)
{
    g_capacity = [real_l_lib GetDiskCapacity];
    return 0;
}

DRESULT disk_read (BYTE pdrv, BYTE *buff, DWORD sector, UINT count)
{
    DRESULT res = RES_OK;
    if(!count)
        return RES_PARERR;
    pthread_mutex_lock(&mutex);
    res = [real_l_lib ReadDisk:sector length:count buffer:buff];
    pthread_mutex_unlock(&mutex);
    return res;
}

DRESULT disk_write (BYTE pdrv,  const BYTE *buff, DWORD sector, UINT count)
{
    DRESULT res = RES_OK;
    if(!count)
        return RES_PARERR;
    pthread_mutex_lock(&mutex);
    res = [real_l_lib WriteDisk:sector length:count buffer:(uint8_t *)buff];
    pthread_mutex_unlock(&mutex);
    return res;
}

DRESULT disk_ioctl (BYTE pdrv, BYTE cmd, void *buff )
{
    return [real_l_lib DiskIoctl:(BYTE)pdrv contrl:(BYTE)cmd buffer:(void*)buff];
}
#endif
