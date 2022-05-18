/*
 * Copyright (c) 2015 Igalia
 * Copyright (c) 2015 Igalia S.L.
 * Copyright (c) 2015 Igalia.
 * Copyright (c) 2015, 2016 Canon Inc. All rights reserved.
 * Copyright (c) 2015, 2016, 2017 Canon Inc.
 * Copyright (c) 2016, 2020 Apple Inc. All rights reserved.
 * Copyright (c) 2022 Codeblog Corp. All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 * 
 */

// DO NOT EDIT THIS FILE. It is automatically generated from JavaScript files for
// builtins by the script: Source/JavaScriptCore/Scripts/generate-js-builtins.py

#include "config.h"
#include "TransformStreamInternalsBuiltins.h"

#include "WebCoreJSClientData.h"
#include <JavaScriptCore/HeapInlines.h>
#include <JavaScriptCore/IdentifierInlines.h>
#include <JavaScriptCore/Intrinsic.h>
#include <JavaScriptCore/JSCJSValueInlines.h>
#include <JavaScriptCore/JSCellInlines.h>
#include <JavaScriptCore/StructureInlines.h>
#include <JavaScriptCore/VM.h>

namespace WebCore {

const JSC::ConstructAbility s_transformStreamInternalsIsTransformStreamCodeConstructAbility = JSC::ConstructAbility::CannotConstruct;
const JSC::ConstructorKind s_transformStreamInternalsIsTransformStreamCodeConstructorKind = JSC::ConstructorKind::None;
const int s_transformStreamInternalsIsTransformStreamCodeLength = 120;
static const JSC::Intrinsic s_transformStreamInternalsIsTransformStreamCodeIntrinsic = JSC::NoIntrinsic;
const char* const s_transformStreamInternalsIsTransformStreamCode =
    "(function (stream)\n" \
    "{\n" \
    "    \"use strict\";\n" \
    "\n" \
    "    return @isObject(stream) && !!@getByIdDirectPrivate(stream, \"readable\");\n" \
    "})\n" \
;

const JSC::ConstructAbility s_transformStreamInternalsIsTransformStreamDefaultControllerCodeConstructAbility = JSC::ConstructAbility::CannotConstruct;
const JSC::ConstructorKind s_transformStreamInternalsIsTransformStreamDefaultControllerCodeConstructorKind = JSC::ConstructorKind::None;
const int s_transformStreamInternalsIsTransformStreamDefaultControllerCodeLength = 142;
static const JSC::Intrinsic s_transformStreamInternalsIsTransformStreamDefaultControllerCodeIntrinsic = JSC::NoIntrinsic;
const char* const s_transformStreamInternalsIsTransformStreamDefaultControllerCode =
    "(function (controller)\n" \
    "{\n" \
    "    \"use strict\";\n" \
    "\n" \
    "    return @isObject(controller) && !!@getByIdDirectPrivate(controller, \"transformAlgorithm\");\n" \
    "})\n" \
;

const JSC::ConstructAbility s_transformStreamInternalsCreateTransformStreamCodeConstructAbility = JSC::ConstructAbility::CannotConstruct;
const JSC::ConstructorKind s_transformStreamInternalsCreateTransformStreamCodeConstructorKind = JSC::ConstructorKind::None;
const int s_transformStreamInternalsCreateTransformStreamCodeLength = 1317;
static const JSC::Intrinsic s_transformStreamInternalsCreateTransformStreamCodeIntrinsic = JSC::NoIntrinsic;
const char* const s_transformStreamInternalsCreateTransformStreamCode =
    "(function (startAlgorithm, transformAlgorithm, flushAlgorithm, writableHighWaterMark, writableSizeAlgorithm, readableHighWaterMark, readableSizeAlgorithm)\n" \
    "{\n" \
    "    if (writableHighWaterMark === @undefined)\n" \
    "        writableHighWaterMark = 1;\n" \
    "    if (writableSizeAlgorithm === @undefined)\n" \
    "        writableSizeAlgorithm = () => 1;\n" \
    "    if (readableHighWaterMark === @undefined)\n" \
    "        readableHighWaterMark = 0;\n" \
    "    if (readableSizeAlgorithm === @undefined)\n" \
    "        readableSizeAlgorithm = () => 1;\n" \
    "    @assert(writableHighWaterMark >= 0);\n" \
    "    @assert(readableHighWaterMark >= 0);\n" \
    "\n" \
    "    const transform = {};\n" \
    "    @putByIdDirectPrivate(transform, \"TransformStream\", true);\n" \
    "\n" \
    "    const stream = new @TransformStream(transform);\n" \
    "    const startPromiseCapability = @newPromiseCapability(@Promise);\n" \
    "    @initializeTransformStream(stream, startPromiseCapability.@promise, writableHighWaterMark, writableSizeAlgorithm, readableHighWaterMark, readableSizeAlgorithm);\n" \
    "\n" \
    "    const controller = new @TransformStreamDefaultController();\n" \
    "    @setUpTransformStreamDefaultController(stream, controller, transformAlgorithm, flushAlgorithm);\n" \
    "\n" \
    "    startAlgorithm().@then(() => {\n" \
    "        startPromiseCapability.@resolve.@call();\n" \
    "    }, (error) => {\n" \
    "        startPromiseCapability.@reject.@call(@undefined, error);\n" \
    "    });\n" \
    "\n" \
    "    return stream;\n" \
    "})\n" \
;

const JSC::ConstructAbility s_transformStreamInternalsInitializeTransformStreamCodeConstructAbility = JSC::ConstructAbility::CannotConstruct;
const JSC::ConstructorKind s_transformStreamInternalsInitializeTransformStreamCodeConstructorKind = JSC::ConstructorKind::None;
const int s_transformStreamInternalsInitializeTransformStreamCodeLength = 1881;
static const JSC::Intrinsic s_transformStreamInternalsInitializeTransformStreamCodeIntrinsic = JSC::NoIntrinsic;
const char* const s_transformStreamInternalsInitializeTransformStreamCode =
    "(function (stream, startPromise, writableHighWaterMark, writableSizeAlgorithm, readableHighWaterMark, readableSizeAlgorithm)\n" \
    "{\n" \
    "    \"use strict\";\n" \
    "\n" \
    "    const startAlgorithm = () => { return startPromise; };\n" \
    "    const writeAlgorithm = (chunk) => { return @transformStreamDefaultSinkWriteAlgorithm(stream, chunk); }\n" \
    "    const abortAlgorithm = (reason) => { return @transformStreamDefaultSinkAbortAlgorithm(stream, reason); }\n" \
    "    const closeAlgorithm = () => { return @transformStreamDefaultSinkCloseAlgorithm(stream); }\n" \
    "    const writable = @createWritableStream(startAlgorithm, writeAlgorithm, closeAlgorithm, abortAlgorithm, writableHighWaterMark, writableSizeAlgorithm);\n" \
    "\n" \
    "    const pullAlgorithm = () => { return @transformStreamDefaultSourcePullAlgorithm(stream); };\n" \
    "    const cancelAlgorithm = (reason) => {\n" \
    "        @transformStreamErrorWritableAndUnblockWrite(stream, reason);\n" \
    "        return @Promise.@resolve();\n" \
    "    };\n" \
    "    const underlyingSource = { };\n" \
    "    @putByIdDirectPrivate(underlyingSource, \"start\", startAlgorithm);\n" \
    "    @putByIdDirectPrivate(underlyingSource, \"pull\", pullAlgorithm);\n" \
    "    @putByIdDirectPrivate(underlyingSource, \"cancel\", cancelAlgorithm);\n" \
    "    const options = { };\n" \
    "    @putByIdDirectPrivate(options, \"size\", readableSizeAlgorithm);\n" \
    "    @putByIdDirectPrivate(options, \"highWaterMark\", readableHighWaterMark);\n" \
    "    const readable = new @ReadableStream(underlyingSource, options);\n" \
    "\n" \
    "    //\n" \
    "    @putByIdDirectPrivate(stream, \"writable\", writable);\n" \
    "    //\n" \
    "    @putByIdDirectPrivate(stream, \"internalWritable\", @getInternalWritableStream(writable));\n" \
    "\n" \
    "    @putByIdDirectPrivate(stream, \"readable\", readable);\n" \
    "    @putByIdDirectPrivate(stream, \"backpressure\", @undefined);\n" \
    "    @putByIdDirectPrivate(stream, \"backpressureChangePromise\", @undefined);\n" \
    "\n" \
    "    @transformStreamSetBackpressure(stream, true);\n" \
    "    @putByIdDirectPrivate(stream, \"controller\", @undefined);\n" \
    "})\n" \
;

const JSC::ConstructAbility s_transformStreamInternalsTransformStreamErrorCodeConstructAbility = JSC::ConstructAbility::CannotConstruct;
const JSC::ConstructorKind s_transformStreamInternalsTransformStreamErrorCodeConstructorKind = JSC::ConstructorKind::None;
const int s_transformStreamInternalsTransformStreamErrorCodeLength = 330;
static const JSC::Intrinsic s_transformStreamInternalsTransformStreamErrorCodeIntrinsic = JSC::NoIntrinsic;
const char* const s_transformStreamInternalsTransformStreamErrorCode =
    "(function (stream, e)\n" \
    "{\n" \
    "    \"use strict\";\n" \
    "\n" \
    "    const readable = @getByIdDirectPrivate(stream, \"readable\");\n" \
    "    const readableController = @getByIdDirectPrivate(readable, \"readableStreamController\");\n" \
    "    @readableStreamDefaultControllerError(readableController, e);\n" \
    "\n" \
    "    @transformStreamErrorWritableAndUnblockWrite(stream, e);\n" \
    "})\n" \
;

const JSC::ConstructAbility s_transformStreamInternalsTransformStreamErrorWritableAndUnblockWriteCodeConstructAbility = JSC::ConstructAbility::CannotConstruct;
const JSC::ConstructorKind s_transformStreamInternalsTransformStreamErrorWritableAndUnblockWriteCodeConstructorKind = JSC::ConstructorKind::None;
const int s_transformStreamInternalsTransformStreamErrorWritableAndUnblockWriteCodeLength = 431;
static const JSC::Intrinsic s_transformStreamInternalsTransformStreamErrorWritableAndUnblockWriteCodeIntrinsic = JSC::NoIntrinsic;
const char* const s_transformStreamInternalsTransformStreamErrorWritableAndUnblockWriteCode =
    "(function (stream, e)\n" \
    "{\n" \
    "    \"use strict\";\n" \
    "\n" \
    "    @transformStreamDefaultControllerClearAlgorithms(@getByIdDirectPrivate(stream, \"controller\"));\n" \
    "\n" \
    "    const writable = @getByIdDirectPrivate(stream, \"internalWritable\");\n" \
    "    @writableStreamDefaultControllerErrorIfNeeded(@getByIdDirectPrivate(writable, \"controller\"), e);\n" \
    "\n" \
    "    if (@getByIdDirectPrivate(stream, \"backpressure\"))\n" \
    "        @transformStreamSetBackpressure(stream, false);\n" \
    "})\n" \
;

const JSC::ConstructAbility s_transformStreamInternalsTransformStreamSetBackpressureCodeConstructAbility = JSC::ConstructAbility::CannotConstruct;
const JSC::ConstructorKind s_transformStreamInternalsTransformStreamSetBackpressureCodeConstructorKind = JSC::ConstructorKind::None;
const int s_transformStreamInternalsTransformStreamSetBackpressureCodeLength = 498;
static const JSC::Intrinsic s_transformStreamInternalsTransformStreamSetBackpressureCodeIntrinsic = JSC::NoIntrinsic;
const char* const s_transformStreamInternalsTransformStreamSetBackpressureCode =
    "(function (stream, backpressure)\n" \
    "{\n" \
    "    \"use strict\";\n" \
    "\n" \
    "    @assert(@getByIdDirectPrivate(stream, \"backpressure\") !== backpressure);\n" \
    "\n" \
    "    const backpressureChangePromise = @getByIdDirectPrivate(stream, \"backpressureChangePromise\");\n" \
    "    if (backpressureChangePromise !== @undefined)\n" \
    "        backpressureChangePromise.@resolve.@call();\n" \
    "\n" \
    "    @putByIdDirectPrivate(stream, \"backpressureChangePromise\", @newPromiseCapability(@Promise));\n" \
    "    @putByIdDirectPrivate(stream, \"backpressure\", backpressure);\n" \
    "})\n" \
;

const JSC::ConstructAbility s_transformStreamInternalsSetUpTransformStreamDefaultControllerCodeConstructAbility = JSC::ConstructAbility::CannotConstruct;
const JSC::ConstructorKind s_transformStreamInternalsSetUpTransformStreamDefaultControllerCodeConstructorKind = JSC::ConstructorKind::None;
const int s_transformStreamInternalsSetUpTransformStreamDefaultControllerCodeLength = 478;
static const JSC::Intrinsic s_transformStreamInternalsSetUpTransformStreamDefaultControllerCodeIntrinsic = JSC::NoIntrinsic;
const char* const s_transformStreamInternalsSetUpTransformStreamDefaultControllerCode =
    "(function (stream, controller, transformAlgorithm, flushAlgorithm)\n" \
    "{\n" \
    "    \"use strict\";\n" \
    "\n" \
    "    @assert(@isTransformStream(stream));\n" \
    "    @assert(@getByIdDirectPrivate(stream, \"controller\") === @undefined);\n" \
    "\n" \
    "    @putByIdDirectPrivate(controller, \"stream\", stream);\n" \
    "    @putByIdDirectPrivate(stream, \"controller\", controller);\n" \
    "    @putByIdDirectPrivate(controller, \"transformAlgorithm\", transformAlgorithm);\n" \
    "    @putByIdDirectPrivate(controller, \"flushAlgorithm\", flushAlgorithm);\n" \
    "})\n" \
;

const JSC::ConstructAbility s_transformStreamInternalsSetUpTransformStreamDefaultControllerFromTransformerCodeConstructAbility = JSC::ConstructAbility::CannotConstruct;
const JSC::ConstructorKind s_transformStreamInternalsSetUpTransformStreamDefaultControllerFromTransformerCodeConstructorKind = JSC::ConstructorKind::None;
const int s_transformStreamInternalsSetUpTransformStreamDefaultControllerFromTransformerCodeLength = 940;
static const JSC::Intrinsic s_transformStreamInternalsSetUpTransformStreamDefaultControllerFromTransformerCodeIntrinsic = JSC::NoIntrinsic;
const char* const s_transformStreamInternalsSetUpTransformStreamDefaultControllerFromTransformerCode =
    "(function (stream, transformer, transformerDict)\n" \
    "{\n" \
    "    \"use strict\";\n" \
    "\n" \
    "    const controller = new @TransformStreamDefaultController();\n" \
    "    let transformAlgorithm = (chunk) => {\n" \
    "        try {\n" \
    "            @transformStreamDefaultControllerEnqueue(controller, chunk);\n" \
    "        } catch (e) {\n" \
    "            return @Promise.@reject(e);\n" \
    "        }\n" \
    "        return @Promise.@resolve();\n" \
    "    };\n" \
    "    let flushAlgorithm = () => { return @Promise.@resolve(); };\n" \
    "\n" \
    "    if (\"transform\" in transformerDict)\n" \
    "        transformAlgorithm = (chunk) => {\n" \
    "            return @promiseInvokeOrNoopMethod(transformer, transformerDict[\"transform\"], [chunk, controller]);\n" \
    "        };\n" \
    "\n" \
    "    if (\"flush\" in transformerDict) {\n" \
    "        flushAlgorithm = () => {\n" \
    "            return @promiseInvokeOrNoopMethod(transformer, transformerDict[\"flush\"], [controller]);\n" \
    "        };\n" \
    "    }\n" \
    "\n" \
    "    @setUpTransformStreamDefaultController(stream, controller, transformAlgorithm, flushAlgorithm);\n" \
    "})\n" \
;

const JSC::ConstructAbility s_transformStreamInternalsTransformStreamDefaultControllerClearAlgorithmsCodeConstructAbility = JSC::ConstructAbility::CannotConstruct;
const JSC::ConstructorKind s_transformStreamInternalsTransformStreamDefaultControllerClearAlgorithmsCodeConstructorKind = JSC::ConstructorKind::None;
const int s_transformStreamInternalsTransformStreamDefaultControllerClearAlgorithmsCodeLength = 190;
static const JSC::Intrinsic s_transformStreamInternalsTransformStreamDefaultControllerClearAlgorithmsCodeIntrinsic = JSC::NoIntrinsic;
const char* const s_transformStreamInternalsTransformStreamDefaultControllerClearAlgorithmsCode =
    "(function (controller)\n" \
    "{\n" \
    "    \"use strict\";\n" \
    "\n" \
    "    //\n" \
    "    @putByIdDirectPrivate(controller, \"transformAlgorithm\", true);\n" \
    "    @putByIdDirectPrivate(controller, \"flushAlgorithm\", @undefined);\n" \
    "})\n" \
;

const JSC::ConstructAbility s_transformStreamInternalsTransformStreamDefaultControllerEnqueueCodeConstructAbility = JSC::ConstructAbility::CannotConstruct;
const JSC::ConstructorKind s_transformStreamInternalsTransformStreamDefaultControllerEnqueueCodeConstructorKind = JSC::ConstructorKind::None;
const int s_transformStreamInternalsTransformStreamDefaultControllerEnqueueCodeLength = 979;
static const JSC::Intrinsic s_transformStreamInternalsTransformStreamDefaultControllerEnqueueCodeIntrinsic = JSC::NoIntrinsic;
const char* const s_transformStreamInternalsTransformStreamDefaultControllerEnqueueCode =
    "(function (controller, chunk)\n" \
    "{\n" \
    "    \"use strict\";\n" \
    "\n" \
    "    const stream = @getByIdDirectPrivate(controller, \"stream\");\n" \
    "    const readable = @getByIdDirectPrivate(stream, \"readable\");\n" \
    "    const readableController = @getByIdDirectPrivate(readable, \"readableStreamController\");\n" \
    "\n" \
    "    @assert(readableController !== @undefined);\n" \
    "    if (!@readableStreamDefaultControllerCanCloseOrEnqueue(readableController))\n" \
    "        @throwTypeError(\"TransformStream.readable cannot close or enqueue\");\n" \
    "\n" \
    "    try {\n" \
    "        @readableStreamDefaultControllerEnqueue(readableController, chunk);\n" \
    "    } catch (e) {\n" \
    "        @transformStreamErrorWritableAndUnblockWrite(stream, e);\n" \
    "        throw @getByIdDirectPrivate(readable, \"storedError\");\n" \
    "    }\n" \
    "\n" \
    "    const backpressure = !@readableStreamDefaultControllerShouldCallPull(readableController);\n" \
    "    if (backpressure !== @getByIdDirectPrivate(stream, \"backpressure\")) {\n" \
    "        @assert(backpressure);\n" \
    "        @transformStreamSetBackpressure(stream, true);\n" \
    "    }\n" \
    "})\n" \
;

const JSC::ConstructAbility s_transformStreamInternalsTransformStreamDefaultControllerErrorCodeConstructAbility = JSC::ConstructAbility::CannotConstruct;
const JSC::ConstructorKind s_transformStreamInternalsTransformStreamDefaultControllerErrorCodeConstructorKind = JSC::ConstructorKind::None;
const int s_transformStreamInternalsTransformStreamDefaultControllerErrorCodeLength = 125;
static const JSC::Intrinsic s_transformStreamInternalsTransformStreamDefaultControllerErrorCodeIntrinsic = JSC::NoIntrinsic;
const char* const s_transformStreamInternalsTransformStreamDefaultControllerErrorCode =
    "(function (controller, e)\n" \
    "{\n" \
    "    \"use strict\";\n" \
    "\n" \
    "    @transformStreamError(@getByIdDirectPrivate(controller, \"stream\"), e);\n" \
    "})\n" \
;

const JSC::ConstructAbility s_transformStreamInternalsTransformStreamDefaultControllerPerformTransformCodeConstructAbility = JSC::ConstructAbility::CannotConstruct;
const JSC::ConstructorKind s_transformStreamInternalsTransformStreamDefaultControllerPerformTransformCodeConstructorKind = JSC::ConstructorKind::None;
const int s_transformStreamInternalsTransformStreamDefaultControllerPerformTransformCodeLength = 500;
static const JSC::Intrinsic s_transformStreamInternalsTransformStreamDefaultControllerPerformTransformCodeIntrinsic = JSC::NoIntrinsic;
const char* const s_transformStreamInternalsTransformStreamDefaultControllerPerformTransformCode =
    "(function (controller, chunk)\n" \
    "{\n" \
    "    \"use strict\";\n" \
    "\n" \
    "    const promiseCapability = @newPromiseCapability(@Promise);\n" \
    "\n" \
    "    const transformPromise = @getByIdDirectPrivate(controller, \"transformAlgorithm\").@call(@undefined, chunk);\n" \
    "    transformPromise.@then(() => {\n" \
    "        promiseCapability.@resolve();\n" \
    "    }, (r) => {\n" \
    "        @transformStreamError(@getByIdDirectPrivate(controller, \"stream\"), r);\n" \
    "        promiseCapability.@reject.@call(@undefined, r);\n" \
    "    });\n" \
    "    return promiseCapability.@promise;\n" \
    "})\n" \
;

const JSC::ConstructAbility s_transformStreamInternalsTransformStreamDefaultControllerTerminateCodeConstructAbility = JSC::ConstructAbility::CannotConstruct;
const JSC::ConstructorKind s_transformStreamInternalsTransformStreamDefaultControllerTerminateCodeConstructorKind = JSC::ConstructorKind::None;
const int s_transformStreamInternalsTransformStreamDefaultControllerTerminateCodeLength = 554;
static const JSC::Intrinsic s_transformStreamInternalsTransformStreamDefaultControllerTerminateCodeIntrinsic = JSC::NoIntrinsic;
const char* const s_transformStreamInternalsTransformStreamDefaultControllerTerminateCode =
    "(function (controller)\n" \
    "{\n" \
    "    \"use strict\";\n" \
    "\n" \
    "    const stream = @getByIdDirectPrivate(controller, \"stream\");\n" \
    "    const readable = @getByIdDirectPrivate(stream, \"readable\");\n" \
    "    const readableController = @getByIdDirectPrivate(readable, \"readableStreamController\");\n" \
    "\n" \
    "    //\n" \
    "    if (@readableStreamDefaultControllerCanCloseOrEnqueue(readableController))\n" \
    "        @readableStreamDefaultControllerClose(readableController);\n" \
    "    const error = @makeTypeError(\"the stream has been terminated\");\n" \
    "    @transformStreamErrorWritableAndUnblockWrite(stream, error);\n" \
    "})\n" \
;

const JSC::ConstructAbility s_transformStreamInternalsTransformStreamDefaultSinkWriteAlgorithmCodeConstructAbility = JSC::ConstructAbility::CannotConstruct;
const JSC::ConstructorKind s_transformStreamInternalsTransformStreamDefaultSinkWriteAlgorithmCodeConstructorKind = JSC::ConstructorKind::None;
const int s_transformStreamInternalsTransformStreamDefaultSinkWriteAlgorithmCodeLength = 1373;
static const JSC::Intrinsic s_transformStreamInternalsTransformStreamDefaultSinkWriteAlgorithmCodeIntrinsic = JSC::NoIntrinsic;
const char* const s_transformStreamInternalsTransformStreamDefaultSinkWriteAlgorithmCode =
    "(function (stream, chunk)\n" \
    "{\n" \
    "    \"use strict\";\n" \
    "\n" \
    "    const writable = @getByIdDirectPrivate(stream, \"internalWritable\");\n" \
    "\n" \
    "    @assert(@getByIdDirectPrivate(writable, \"state\") === \"writable\");\n" \
    "\n" \
    "    const controller = @getByIdDirectPrivate(stream, \"controller\");\n" \
    "\n" \
    "    if (@getByIdDirectPrivate(stream, \"backpressure\")) {\n" \
    "        const promiseCapability = @newPromiseCapability(@Promise);\n" \
    "\n" \
    "        const backpressureChangePromise = @getByIdDirectPrivate(stream, \"backpressureChangePromise\");\n" \
    "        @assert(backpressureChangePromise !== @undefined);\n" \
    "        backpressureChangePromise.@promise.@then(() => {\n" \
    "            const state = @getByIdDirectPrivate(writable, \"state\");\n" \
    "            if (state === \"erroring\") {\n" \
    "                promiseCapability.@reject.@call(@undefined, @getByIdDirectPrivate(writable, \"storedError\"));\n" \
    "                return;\n" \
    "            }\n" \
    "\n" \
    "            @assert(state === \"writable\");\n" \
    "            @transformStreamDefaultControllerPerformTransform(controller, chunk).@then(() => {\n" \
    "                promiseCapability.@resolve();\n" \
    "            }, (e) => {\n" \
    "                promiseCapability.@reject.@call(@undefined, e);\n" \
    "            });\n" \
    "        }, (e) => {\n" \
    "            promiseCapability.@reject.@call(@undefined, e);\n" \
    "        });\n" \
    "\n" \
    "        return promiseCapability.@promise;\n" \
    "    }\n" \
    "    return @transformStreamDefaultControllerPerformTransform(controller, chunk);\n" \
    "})\n" \
;

const JSC::ConstructAbility s_transformStreamInternalsTransformStreamDefaultSinkAbortAlgorithmCodeConstructAbility = JSC::ConstructAbility::CannotConstruct;
const JSC::ConstructorKind s_transformStreamInternalsTransformStreamDefaultSinkAbortAlgorithmCodeConstructorKind = JSC::ConstructorKind::None;
const int s_transformStreamInternalsTransformStreamDefaultSinkAbortAlgorithmCodeLength = 126;
static const JSC::Intrinsic s_transformStreamInternalsTransformStreamDefaultSinkAbortAlgorithmCodeIntrinsic = JSC::NoIntrinsic;
const char* const s_transformStreamInternalsTransformStreamDefaultSinkAbortAlgorithmCode =
    "(function (stream, reason)\n" \
    "{\n" \
    "    \"use strict\";\n" \
    "\n" \
    "    @transformStreamError(stream, reason);\n" \
    "    return @Promise.@resolve();\n" \
    "})\n" \
;

const JSC::ConstructAbility s_transformStreamInternalsTransformStreamDefaultSinkCloseAlgorithmCodeConstructAbility = JSC::ConstructAbility::CannotConstruct;
const JSC::ConstructorKind s_transformStreamInternalsTransformStreamDefaultSinkCloseAlgorithmCodeConstructorKind = JSC::ConstructorKind::None;
const int s_transformStreamInternalsTransformStreamDefaultSinkCloseAlgorithmCodeLength = 1295;
static const JSC::Intrinsic s_transformStreamInternalsTransformStreamDefaultSinkCloseAlgorithmCodeIntrinsic = JSC::NoIntrinsic;
const char* const s_transformStreamInternalsTransformStreamDefaultSinkCloseAlgorithmCode =
    "(function (stream)\n" \
    "{\n" \
    "    \"use strict\";\n" \
    "    const readable = @getByIdDirectPrivate(stream, \"readable\");\n" \
    "    const controller = @getByIdDirectPrivate(stream, \"controller\");\n" \
    "    const readableController = @getByIdDirectPrivate(readable, \"readableStreamController\");\n" \
    "\n" \
    "    const flushAlgorithm = @getByIdDirectPrivate(controller, \"flushAlgorithm\");\n" \
    "    @assert(flushAlgorithm !== @undefined);\n" \
    "    const flushPromise = @getByIdDirectPrivate(controller, \"flushAlgorithm\").@call();\n" \
    "    @transformStreamDefaultControllerClearAlgorithms(controller);\n" \
    "\n" \
    "    const promiseCapability = @newPromiseCapability(@Promise);\n" \
    "    flushPromise.@then(() => {\n" \
    "        if (@getByIdDirectPrivate(readable, \"state\") === @streamErrored) {\n" \
    "            promiseCapability.@reject.@call(@undefined, @getByIdDirectPrivate(readable, \"storedError\"));\n" \
    "            return;\n" \
    "        }\n" \
    "\n" \
    "        //\n" \
    "        if (@readableStreamDefaultControllerCanCloseOrEnqueue(readableController))\n" \
    "            @readableStreamDefaultControllerClose(readableController);\n" \
    "        promiseCapability.@resolve();\n" \
    "    }, (r) => {\n" \
    "        @transformStreamError(@getByIdDirectPrivate(controller, \"stream\"), r);\n" \
    "        promiseCapability.@reject.@call(@undefined, @getByIdDirectPrivate(readable, \"storedError\"));\n" \
    "    });\n" \
    "    return promiseCapability.@promise;\n" \
    "})\n" \
;

const JSC::ConstructAbility s_transformStreamInternalsTransformStreamDefaultSourcePullAlgorithmCodeConstructAbility = JSC::ConstructAbility::CannotConstruct;
const JSC::ConstructorKind s_transformStreamInternalsTransformStreamDefaultSourcePullAlgorithmCodeConstructorKind = JSC::ConstructorKind::None;
const int s_transformStreamInternalsTransformStreamDefaultSourcePullAlgorithmCodeLength = 325;
static const JSC::Intrinsic s_transformStreamInternalsTransformStreamDefaultSourcePullAlgorithmCodeIntrinsic = JSC::NoIntrinsic;
const char* const s_transformStreamInternalsTransformStreamDefaultSourcePullAlgorithmCode =
    "(function (stream)\n" \
    "{\n" \
    "    \"use strict\";\n" \
    "\n" \
    "    @assert(@getByIdDirectPrivate(stream, \"backpressure\"));\n" \
    "    @assert(@getByIdDirectPrivate(stream, \"backpressureChangePromise\") !== @undefined);\n" \
    "\n" \
    "    @transformStreamSetBackpressure(stream, false);\n" \
    "\n" \
    "    return @getByIdDirectPrivate(stream, \"backpressureChangePromise\").@promise;\n" \
    "})\n" \
;


#define DEFINE_BUILTIN_GENERATOR(codeName, functionName, overriddenName, argumentCount) \
JSC::FunctionExecutable* codeName##Generator(JSC::VM& vm) \
{\
    JSVMClientData* clientData = static_cast<JSVMClientData*>(vm.clientData); \
    return clientData->builtinFunctions().transformStreamInternalsBuiltins().codeName##Executable()->link(vm, nullptr, clientData->builtinFunctions().transformStreamInternalsBuiltins().codeName##Source(), std::nullopt, s_##codeName##Intrinsic); \
}
WEBCORE_FOREACH_TRANSFORMSTREAMINTERNALS_BUILTIN_CODE(DEFINE_BUILTIN_GENERATOR)
#undef DEFINE_BUILTIN_GENERATOR


} // namespace WebCore
