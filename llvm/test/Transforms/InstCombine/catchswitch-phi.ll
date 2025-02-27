; NOTE: Assertions have been autogenerated by utils/update_test_checks.py
; RUN: opt < %s -passes=instcombine -S | FileCheck %s

target datalayout = "e-m:e-p:32:32-i64:64-n32:64-S128-ni:1"
target triple = "wasm32-unknown-unknown"

%struct.quux = type { i32 }
%struct.blam = type <{ i32, %struct.quux }>

declare void @foo()
declare void @bar(ptr)
declare i32 @baz()
declare i32 @__gxx_wasm_personality_v0(...)
; Function Attrs: noreturn
declare void @llvm.wasm.rethrow() #0

; Test that a PHI in catchswitch BB are excluded from combining into a non-PHI
; instruction.
define void @test0(i1 %c1) personality ptr @__gxx_wasm_personality_v0 {
; CHECK-LABEL: @test0(
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[TMP0:%.*]] = alloca [[STRUCT_BLAM:%.*]], align 4
; CHECK-NEXT:    br i1 [[C1:%.*]], label [[BB1:%.*]], label [[BB2:%.*]]
; CHECK:       bb1:
; CHECK-NEXT:    [[TMP1:%.*]] = getelementptr inbounds nuw i8, ptr [[TMP0]], i32 4
; CHECK-NEXT:    invoke void @foo()
; CHECK-NEXT:            to label [[BB3:%.*]] unwind label [[BB4:%.*]]
; CHECK:       bb2:
; CHECK-NEXT:    [[TMP2:%.*]] = getelementptr inbounds nuw i8, ptr [[TMP0]], i32 4
; CHECK-NEXT:    invoke void @foo()
; CHECK-NEXT:            to label [[BB3]] unwind label [[BB4]]
; CHECK:       bb3:
; CHECK-NEXT:    unreachable
; CHECK:       bb4:
; CHECK-NEXT:    [[TMP3:%.*]] = phi ptr [ [[TMP1]], [[BB1]] ], [ [[TMP2]], [[BB2]] ]
; CHECK-NEXT:    [[TMP4:%.*]] = catchswitch within none [label %bb5] unwind label [[BB7:%.*]]
; CHECK:       bb5:
; CHECK-NEXT:    [[TMP5:%.*]] = catchpad within [[TMP4]] [ptr null]
; CHECK-NEXT:    invoke void @foo() [ "funclet"(token [[TMP5]]) ]
; CHECK-NEXT:            to label [[BB6:%.*]] unwind label [[BB7]]
; CHECK:       bb6:
; CHECK-NEXT:    unreachable
; CHECK:       bb7:
; CHECK-NEXT:    [[TMP6:%.*]] = cleanuppad within none []
; CHECK-NEXT:    call void @bar(ptr nonnull [[TMP3]]) [ "funclet"(token [[TMP6]]) ]
; CHECK-NEXT:    unreachable
;
bb:
  %tmp0 = alloca %struct.blam, align 4
  br i1 %c1, label %bb1, label %bb2

bb1:                                              ; preds = %bb
  %tmp1 = getelementptr inbounds %struct.blam, ptr %tmp0, i32 0, i32 1
  invoke void @foo()
  to label %bb3 unwind label %bb4

bb2:                                              ; preds = %bb
  %tmp2 = getelementptr inbounds %struct.blam, ptr %tmp0, i32 0, i32 1
  invoke void @foo()
  to label %bb3 unwind label %bb4

bb3:                                              ; preds = %bb2, %bb1
  unreachable

bb4:                                              ; preds = %bb2, %bb1
  ; This PHI should not be combined into a non-PHI instruction, because
  ; catchswitch BB cannot have any non-PHI instruction other than catchswitch
  ; itself.
  %tmp3 = phi ptr [ %tmp1, %bb1 ], [ %tmp2, %bb2 ]
  %tmp4 = catchswitch within none [label %bb5] unwind label %bb7

bb5:                                              ; preds = %bb4
  %tmp5 = catchpad within %tmp4 [ptr null]
  invoke void @foo() [ "funclet"(token %tmp5) ]
  to label %bb6 unwind label %bb7

bb6:                                              ; preds = %bb5
  unreachable

bb7:                                              ; preds = %bb5, %bb4
  %tmp6 = cleanuppad within none []
  call void @bar(ptr %tmp3) [ "funclet"(token %tmp6) ]
  unreachable
}

; Test that slicing-up of illegal integer type PHI does not happen in catchswitch
; BBs, which can't have any non-PHI instruction before the catchswitch.
define void @test1() personality ptr @__gxx_wasm_personality_v0 {
; CHECK-LABEL: @test1(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    invoke void @foo()
; CHECK-NEXT:            to label [[INVOKE_CONT:%.*]] unwind label [[CATCH_DISPATCH1:%.*]]
; CHECK:       invoke.cont:
; CHECK-NEXT:    [[CALL:%.*]] = invoke i32 @baz()
; CHECK-NEXT:            to label [[INVOKE_CONT1:%.*]] unwind label [[CATCH_DISPATCH:%.*]]
; CHECK:       invoke.cont1:
; CHECK-NEXT:    [[TOBOOL_NOT:%.*]] = icmp eq i32 [[CALL]], 0
; CHECK-NEXT:    br i1 [[TOBOOL_NOT]], label [[IF_END:%.*]], label [[IF_THEN:%.*]]
; CHECK:       if.then:
; CHECK-NEXT:    br label [[IF_END]]
; CHECK:       if.end:
; CHECK-NEXT:    [[AP_0:%.*]] = phi i8 [ 1, [[IF_THEN]] ], [ 0, [[INVOKE_CONT1]] ]
; CHECK-NEXT:    invoke void @foo()
; CHECK-NEXT:            to label [[INVOKE_CONT2:%.*]] unwind label [[CATCH_DISPATCH]]
; CHECK:       invoke.cont2:
; CHECK-NEXT:    br label [[TRY_CONT:%.*]]
; CHECK:       catch.dispatch:
; CHECK-NEXT:    [[AP_1:%.*]] = phi i8 [ [[AP_0]], [[IF_END]] ], [ 0, [[INVOKE_CONT]] ]
; CHECK-NEXT:    [[TMP0:%.*]] = catchswitch within none [label %catch.start] unwind label [[CATCH_DISPATCH1]]
; CHECK:       catch.start:
; CHECK-NEXT:    [[TMP1:%.*]] = catchpad within [[TMP0]] [ptr null]
; CHECK-NEXT:    br i1 false, label [[CATCH:%.*]], label [[RETHROW:%.*]]
; CHECK:       catch:
; CHECK-NEXT:    catchret from [[TMP1]] to label [[TRY_CONT]]
; CHECK:       rethrow:
; CHECK-NEXT:    invoke void @llvm.wasm.rethrow() #[[ATTR0:[0-9]+]] [ "funclet"(token [[TMP1]]) ]
; CHECK-NEXT:            to label [[UNREACHABLE:%.*]] unwind label [[CATCH_DISPATCH1]]
; CHECK:       catch.dispatch1:
; CHECK-NEXT:    [[AP_2:%.*]] = phi i8 [ [[AP_1]], [[CATCH_DISPATCH]] ], [ [[AP_1]], [[RETHROW]] ], [ 0, [[ENTRY:%.*]] ]
; CHECK-NEXT:    [[TMP2:%.*]] = catchswitch within none [label %catch.start1] unwind to caller
; CHECK:       catch.start1:
; CHECK-NEXT:    [[TMP3:%.*]] = catchpad within [[TMP2]] [ptr null]
; CHECK-NEXT:    [[TOBOOL1:%.*]] = trunc i8 [[AP_2]] to i1
; CHECK-NEXT:    br i1 [[TOBOOL1]], label [[IF_THEN1:%.*]], label [[IF_END1:%.*]]
; CHECK:       if.then1:
; CHECK-NEXT:    br label [[IF_END1]]
; CHECK:       if.end1:
; CHECK-NEXT:    catchret from [[TMP3]] to label [[TRY_CONT]]
; CHECK:       try.cont:
; CHECK-NEXT:    ret void
; CHECK:       unreachable:
; CHECK-NEXT:    unreachable
;
entry:
  invoke void @foo()
  to label %invoke.cont unwind label %catch.dispatch1

invoke.cont:                                      ; preds = %entry
  %call = invoke i32 @baz()
  to label %invoke.cont1 unwind label %catch.dispatch

invoke.cont1:                                     ; preds = %invoke.cont
  %tobool = icmp ne i32 %call, 0
  br i1 %tobool, label %if.then, label %if.end

if.then:                                          ; preds = %invoke.cont1
  br label %if.end

if.end:                                           ; preds = %if.then, %invoke.cont1
  %ap.0 = phi i8 [ 1, %if.then ], [ 0, %invoke.cont1 ]
  invoke void @foo()
  to label %invoke.cont2 unwind label %catch.dispatch

invoke.cont2:                                     ; preds = %if.end
  br label %try.cont

catch.dispatch:                                   ; preds = %if.end, %invoke.cont
  ; %ap.2 in catch.dispatch1 BB has an illegal integer type (i8) in the data
  ; layout, and it is only used by trunc or trunc(lshr) operations. In this case
  ; InstCombine will split this PHI in its predecessors, which include this
  ; catch.dispatch BB. This splitting involves creating non-PHI instructions,
  ; such as 'and' or 'icmp' in this BB, which is not valid for a catchswitch BB.
  ; So if one of sliced-up PHI's predecessor is a catchswitch block, we don't
  ; optimize that case and bail out. This BB should be preserved intact after
  ; InstCombine and the pass shouldn't produce invalid code.
  %ap.1 = phi i8 [ %ap.0, %if.end ], [ 0, %invoke.cont ]
  %tmp0 = catchswitch within none [label %catch.start] unwind label %catch.dispatch1

catch.start:                                      ; preds = %catch.dispatch
  %tmp1 = catchpad within %tmp0 [ptr null]
  br i1 0, label %catch, label %rethrow

catch:                                            ; preds = %catch.start
  catchret from %tmp1 to label %try.cont

rethrow:                                          ; preds = %catch.start
  invoke void @llvm.wasm.rethrow() #0 [ "funclet"(token %tmp1) ]
  to label %unreachable unwind label %catch.dispatch1

catch.dispatch1:                                  ; preds = %rethrow, %catch.dispatch, %entry
  %ap.2 = phi i8 [ %ap.1, %catch.dispatch ], [ %ap.1, %rethrow ], [ 0, %entry ]
  %tmp2 = catchswitch within none [label %catch.start1] unwind to caller

catch.start1:                                     ; preds = %catch.dispatch1
  %tmp3 = catchpad within %tmp2 [ptr null]
  %tobool1 = trunc i8 %ap.2 to i1
  br i1 %tobool1, label %if.then1, label %if.end1

if.then1:                                         ; preds = %catch.start1
  br label %if.end1

if.end1:                                          ; preds = %if.then1, %catch.start1
  catchret from %tmp3 to label %try.cont

try.cont:                                         ; preds = %if.end1, %catch, %invoke.cont2
  ret void

unreachable:                                      ; preds = %rethrow
  unreachable
}

attributes #0 = { noreturn }
