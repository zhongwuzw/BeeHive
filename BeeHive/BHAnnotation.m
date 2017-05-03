/**
 * Created by BeeHive.
 * Copyright (c) 2016, Alibaba, Inc. All rights reserved.
 *
 * This source code is licensed under the GNU GENERAL PUBLIC LICENSE.
 * For the full copyright and license information,please view the LICENSE file in the root directory of this source tree.
 */


#import "BHAnnotation.h"
#import "BHCommon.h"
#include <mach-o/getsect.h>
#include <mach-o/loader.h>
#include <mach-o/dyld.h>
#include <dlfcn.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <mach-o/ldsyms.h>

@implementation BHAnnotation

NSArray<NSString *>* BHReadConfiguration(char *sectionName,const struct mach_header *mhp);

+ (void)load{
    uint32_t image_count = _dyld_image_count();
    for (uint32_t image_index = 0; image_index < image_count; image_index++) {
        const struct mach_header *mhp = (const struct mach_header *)_dyld_get_image_header(image_index);
        
        NSArray *mods = BHReadConfiguration(BeehiveModSectName, mhp);
        for (NSString *modName in mods) {
            Class cls;
            if (modName) {
                cls = NSClassFromString(modName);
                
                if (cls) {
                    [[BHModuleManager sharedManager] registerDynamicModule:cls];
                }
            }
        }
        
        //register services
        NSArray<NSString *> *services = BHReadConfiguration(BeehiveServiceSectName,mhp);
        for (NSString *map in services) {
            NSData *jsonData =  [map dataUsingEncoding:NSUTF8StringEncoding];
            NSError *error = nil;
            id json = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
            if (!error) {
                if ([json isKindOfClass:[NSDictionary class]] && [json allKeys].count) {
                    
                    NSString *protocol = [json allKeys][0];
                    NSString *clsName  = [json allValues][0];
                    
                    if (protocol && clsName) {
                        [[BHServiceManager sharedManager] registerService:NSProtocolFromString(protocol) implClass:NSClassFromString(clsName)];
                    }
                    
                }
            }
        }
    }
}

NSArray<NSString *>* BHReadConfiguration(char *sectionName,const struct mach_header *mhp)
{
    NSMutableArray *configs = [NSMutableArray array];
    unsigned long size = 0;
#ifndef __LP64__
    uintptr_t *memory = (uintptr_t*)getsectiondata(mhp, SEG_DATA, sectionName, &size);
#else
    const struct mach_header_64 *mhp64 = (const struct mach_header_64 *)mhp;
    uintptr_t *memory = (uintptr_t*)getsectiondata(mhp64, SEG_DATA, sectionName, &size);
#endif
    
    unsigned long counter = size/sizeof(void*);
    for(int idx = 0; idx < counter; ++idx){
        char *string = (char*)memory[idx];
        NSString *str = [NSString stringWithUTF8String:string];
        if(!str)continue;
        
        BHLog(@"config = %@", str);
        if(str) [configs addObject:str];
    }
    
    return configs;
}

@end


