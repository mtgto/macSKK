// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#import <CoreServices/CoreServices.h>

// Dictionary.appで有効になっている辞書を返す
NSArray * _Nonnull DCSGetActiveDictionaries();
// Dictionary.appで無効になっているものを含めて利用可能な辞書を返す
NSSet * _Nonnull DCSCopyAvailableDictionaries();
NSString * _Nullable DCSDictionaryGetName(DCSDictionaryRef _Nullable dictID);
NSString * _Nullable DCSDictionaryGetIdentifier(DCSDictionaryRef _Nullable dictID);
