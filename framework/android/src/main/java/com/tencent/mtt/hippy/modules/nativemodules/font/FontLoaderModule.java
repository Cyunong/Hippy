/* Tencent is pleased to support the open source community by making Hippy available.
 * Copyright (C) 2018 THL A29 Limited, a Tencent company. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.tencent.mtt.hippy.modules.nativemodules.font;

import com.openhippy.connector.RenderConnector;
import com.tencent.mtt.hippy.HippyEngineContext;
import com.tencent.mtt.hippy.annotation.HippyMethod;
import com.tencent.mtt.hippy.annotation.HippyNativeModule;
import com.tencent.mtt.hippy.modules.Promise;
import com.tencent.mtt.hippy.modules.nativemodules.HippyNativeModuleBase;

@HippyNativeModule(name = "FontLoaderModule")
public class FontLoaderModule extends HippyNativeModuleBase {

    private final int rootId;

    public FontLoaderModule(HippyEngineContext context) {
        super(context);
        rootId = context.getRootView().getId();
    }

    @HippyMethod(name = "load")
    public void load(final String fontFamily, final String fontUrl, final Promise promise) {
        RenderConnector renderer = mContext.getRenderer();
        renderer.loadFontAndRefreshWindow(fontFamily, fontUrl, rootId, promise);
    }
}
