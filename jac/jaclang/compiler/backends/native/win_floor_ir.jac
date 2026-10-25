glob WIN_FLOOR_KERNEL32: list[str] = [
         "FlsAlloc",
         "FlsGetValue",
         "FlsSetValue",
         "SetConsoleOutputCP",
         "SetConsoleCP",
         "GetLastError",
         "MultiByteToWideChar",
         "WideCharToMultiByte",
         "MoveFileExW",
         "GetSystemTimePreciseAsFileTime",
         "QueryPerformanceCounter",
         "QueryPerformanceFrequency",
         "GetCurrentProcess",
         "GetCurrentThread",
         "GetProcessTimes",
         "GetThreadTimes",
         "Sleep",
         "CreateWaitableTimerExW",
         "SetWaitableTimer",
         "WaitForSingleObject",
         "CloseHandle",
         "CreateThread",
         "LoadLibraryW",
         "GetProcAddress",
         "FreeLibrary",
         "GetModuleHandleW",
         "GetModuleFileNameW"
     ],
     WIN_FLOOR_IR: str = r"""
%struct.ucrt_stat64 = type { i32, i16, i16, i16, i16, i16, i32, i64, i64, i64, i64 }
%struct.linux_timespec = type { i64, i64 }
%struct.linux_stat = type { i64, i64, i64, i32, i32, i32, i32, i64, i64, i64, i64, %struct.linux_timespec, %struct.linux_timespec, %struct.linux_timespec, [3 x i64] }
%struct.linux_passwd = type { ptr, ptr, i32, i32, ptr, ptr, ptr }

$"??_C@_00CNPNBAHC@?$AA@" = comdat any

$"??_C@_08JMMIJEMM@USERNAME?$AA@" = comdat any

$"??_C@_03JCIJEFNJ@UTC?$AA@" = comdat any

$"??_C@_0BB@OGGFDLON@Windows?5error?5?$CFu?$AA@" = comdat any

$"??_C@_06PFLEPMKG@?4UTF?98?$AA@" = comdat any

$"??_C@_0M@DPNKMMOG@USERPROFILE?$AA@" = comdat any

@stdout = dso_local local_unnamed_addr global ptr null, align 8
@"??_C@_00CNPNBAHC@?$AA@" = linkonce_odr dso_local unnamed_addr constant [1 x i8] zeroinitializer, comdat, align 1
@"??_C@_08JMMIJEMM@USERNAME?$AA@" = linkonce_odr dso_local unnamed_addr constant [9 x i8] c"USERNAME\00", comdat, align 1
@"??_C@_03JCIJEFNJ@UTC?$AA@" = linkonce_odr dso_local unnamed_addr constant [4 x i8] c"UTC\00", comdat, align 1
@dl_last_error = internal unnamed_addr global i32 0, align 4
@dlerror.text = internal global [48 x i8] zeroinitializer, align 16
@"??_C@_0BB@OGGFDLON@Windows?5error?5?$CFu?$AA@" = linkonce_odr dso_local unnamed_addr constant [17 x i8] c"Windows error %u\00", comdat, align 1
@stdin = dso_local local_unnamed_addr global ptr null, align 8
@stderr = dso_local local_unnamed_addr global ptr null, align 8
@"??_C@_06PFLEPMKG@?4UTF?98?$AA@" = linkonce_odr dso_local unnamed_addr constant [7 x i8] c".UTF-8\00", comdat, align 1
@"??_C@_0M@DPNKMMOG@USERPROFILE?$AA@" = linkonce_odr dso_local unnamed_addr constant [12 x i8] c"USERPROFILE\00", comdat, align 1
@switch.table.__jac_addrinfo_layout = private unnamed_addr constant [5 x i64] [i64 16, i64 32, i64 40, i64 48, i64 23], align 8
@switch.table.__jac_clock_id = private unnamed_addr constant [6 x i64] [i64 0, i64 1, i64 2, i64 3, i64 4, i64 1], align 8

define dso_local ptr @__errno_location() local_unnamed_addr #0 {
  %1 = tail call ptr @_errno() #10
  ret ptr %1
}

declare dso_local ptr @_errno() local_unnamed_addr #1

define dso_local ptr @memmem(ptr noundef %0, i64 noundef %1, ptr noundef %2, i64 noundef %3) local_unnamed_addr #0 {
  %5 = icmp eq i64 %3, 0
  br i1 %5, label %27, label %6

6:                                                ; preds = %4
  %7 = icmp ult i64 %1, %3
  br i1 %7, label %27, label %8

8:                                                ; preds = %6
  %9 = sub nuw i64 %1, %3
  %10 = getelementptr inbounds nuw i8, ptr %0, i64 %9
  %11 = ptrtoint ptr %10 to i64
  %12 = add i64 %11, 1
  br label %13

13:                                               ; preds = %8, %24
  %14 = phi ptr [ %0, %8 ], [ %25, %24 ]
  %15 = ptrtoint ptr %14 to i64
  %16 = sub i64 %12, %15
  %17 = load i8, ptr %2, align 1
  %18 = zext i8 %17 to i32
  %19 = tail call ptr @memchr(ptr noundef %14, i32 noundef %18, i64 noundef %16) #10
  %20 = icmp eq ptr %19, null
  br i1 %20, label %27, label %21

21:                                               ; preds = %13
  %22 = tail call i32 @memcmp(ptr noundef nonnull %19, ptr noundef nonnull %2, i64 noundef %3) #10
  %23 = icmp eq i32 %22, 0
  br i1 %23, label %27, label %24

24:                                               ; preds = %21
  %25 = getelementptr inbounds nuw i8, ptr %19, i64 1
  %26 = icmp ugt ptr %25, %10
  br i1 %26, label %27, label %13

27:                                               ; preds = %24, %13, %21, %6, %4
  %28 = phi ptr [ %0, %4 ], [ null, %6 ], [ null, %24 ], [ null, %13 ], [ %19, %21 ]
  ret ptr %28
}

declare void @llvm.lifetime.start.p0(i64 immarg, ptr captures(none)) #2

declare dso_local ptr @memchr(ptr noundef, i32 noundef, i64 noundef) local_unnamed_addr #1

declare dso_local i32 @memcmp(ptr noundef, ptr noundef, i64 noundef) local_unnamed_addr #1

declare void @llvm.lifetime.end.p0(i64 immarg, ptr captures(none)) #2

define dso_local i32 @printf(ptr noundef %0, ...) local_unnamed_addr #0 {
  %2 = alloca ptr, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr nonnull %2) #11
  call void @llvm.va_start.p0(ptr nonnull %2)
  %3 = load ptr, ptr %2, align 8
  %4 = load ptr, ptr @stdout, align 8
  %5 = call i32 @__stdio_common_vfprintf(i64 noundef 0, ptr noundef %4, ptr noundef %0, ptr noundef null, ptr noundef %3) #10
  call void @llvm.va_end.p0(ptr nonnull %2)
  call void @llvm.lifetime.end.p0(i64 8, ptr nonnull %2) #11
  ret i32 %5
}

declare void @llvm.va_start.p0(ptr) #3

declare dso_local i32 @__stdio_common_vfprintf(i64 noundef, ptr noundef, ptr noundef, ptr noundef, ptr noundef) local_unnamed_addr #1

declare void @llvm.va_end.p0(ptr) #3

define dso_local i32 @fprintf(ptr noundef %0, ptr noundef %1, ...) local_unnamed_addr #0 {
  %3 = alloca ptr, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr nonnull %3) #11
  call void @llvm.va_start.p0(ptr nonnull %3)
  %4 = load ptr, ptr %3, align 8
  %5 = call i32 @__stdio_common_vfprintf(i64 noundef 0, ptr noundef %0, ptr noundef %1, ptr noundef null, ptr noundef %4) #10
  call void @llvm.va_end.p0(ptr nonnull %3)
  call void @llvm.lifetime.end.p0(i64 8, ptr nonnull %3) #11
  ret i32 %5
}

define dso_local range(i32 -1, -2147483648) i32 @vsnprintf(ptr noundef %0, i64 noundef %1, ptr noundef %2, ptr noundef %3) local_unnamed_addr #0 {
  %5 = tail call i32 @__stdio_common_vsprintf(i64 noundef 2, ptr noundef %0, i64 noundef %1, ptr noundef %2, ptr noundef null, ptr noundef %3) #10
  %6 = tail call i32 @llvm.smax.i32(i32 %5, i32 -1)
  ret i32 %6
}

declare dso_local i32 @__stdio_common_vsprintf(i64 noundef, ptr noundef, i64 noundef, ptr noundef, ptr noundef, ptr noundef) local_unnamed_addr #1

define dso_local range(i32 -1, -2147483648) i32 @snprintf(ptr noundef %0, i64 noundef %1, ptr noundef %2, ...) local_unnamed_addr #0 {
  %4 = alloca ptr, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr nonnull %4) #11
  call void @llvm.va_start.p0(ptr nonnull %4)
  %5 = load ptr, ptr %4, align 8
  %6 = call i32 @__stdio_common_vsprintf(i64 noundef 2, ptr noundef %0, i64 noundef %1, ptr noundef %2, ptr noundef null, ptr noundef %5) #10
  %7 = call range(i32 -1, -2147483648) i32 @llvm.smax.i32(i32 %6, i32 -1)
  call void @llvm.va_end.p0(ptr nonnull %4)
  call void @llvm.lifetime.end.p0(i64 8, ptr nonnull %4) #11
  ret i32 %7
}

define dso_local range(i32 -1, -2147483648) i32 @sprintf(ptr noundef %0, ptr noundef %1, ...) local_unnamed_addr #0 {
  %3 = alloca ptr, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr nonnull %3) #11
  call void @llvm.va_start.p0(ptr nonnull %3)
  %4 = load ptr, ptr %3, align 8
  %5 = call i32 @__stdio_common_vsprintf(i64 noundef 2, ptr noundef %0, i64 noundef -1, ptr noundef %1, ptr noundef null, ptr noundef %4) #10
  %6 = call range(i32 -1, -2147483648) i32 @llvm.smax.i32(i32 %5, i32 -1)
  call void @llvm.va_end.p0(ptr nonnull %3)
  call void @llvm.lifetime.end.p0(i64 8, ptr nonnull %3) #11
  ret i32 %6
}

define dso_local i32 @sscanf(ptr noundef %0, ptr noundef %1, ...) local_unnamed_addr #0 {
  %3 = alloca ptr, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr nonnull %3) #11
  call void @llvm.va_start.p0(ptr nonnull %3)
  %4 = load ptr, ptr %3, align 8
  %5 = call i32 @__stdio_common_vsscanf(i64 noundef 0, ptr noundef %0, i64 noundef -1, ptr noundef %1, ptr noundef null, ptr noundef %4) #10
  call void @llvm.va_end.p0(ptr nonnull %3)
  call void @llvm.lifetime.end.p0(i64 8, ptr nonnull %3) #11
  ret i32 %5
}

declare dso_local i32 @__stdio_common_vsscanf(i64 noundef, ptr noundef, i64 noundef, ptr noundef, ptr noundef, ptr noundef) local_unnamed_addr #1

define dso_local ptr @fopen(ptr noundef %0, ptr noundef %1) local_unnamed_addr #0 {
  %3 = alloca [16 x i8], align 16
  call void @llvm.lifetime.start.p0(i64 16, ptr nonnull %3) #11
  %4 = tail call i64 @strlen(ptr noundef %1) #10
  %5 = icmp ugt i64 %4, 12
  br i1 %5, label %13, label %6

6:                                                ; preds = %2
  %7 = icmp eq i64 %4, 0
  br i1 %7, label %65, label %8

8:                                                ; preds = %6
  %9 = and i64 %4, 3
  %10 = icmp ult i64 %4, 4
  br i1 %10, label %15, label %11

11:                                               ; preds = %8
  %12 = and i64 %4, 12
  br label %35

13:                                               ; preds = %2
  %14 = tail call ptr @_errno() #10
  store i32 22, ptr %14, align 4
  br label %72

15:                                               ; preds = %35, %8
  %16 = phi i32 [ poison, %8 ], [ %61, %35 ]
  %17 = phi i64 [ 0, %8 ], [ %62, %35 ]
  %18 = phi i32 [ 0, %8 ], [ %61, %35 ]
  %19 = icmp eq i64 %9, 0
  br i1 %19, label %32, label %20

20:                                               ; preds = %15, %20
  %21 = phi i64 [ %29, %20 ], [ %17, %15 ]
  %22 = phi i32 [ %28, %20 ], [ %18, %15 ]
  %23 = phi i64 [ %30, %20 ], [ 0, %15 ]
  %24 = getelementptr inbounds nuw i8, ptr %1, i64 %21
  %25 = load i8, ptr %24, align 1
  %26 = getelementptr inbounds nuw [16 x i8], ptr %3, i64 0, i64 %21
  store i8 %25, ptr %26, align 1
  %27 = icmp eq i8 %25, 98
  %28 = select i1 %27, i32 1, i32 %22
  %29 = add nuw nsw i64 %21, 1
  %30 = add i64 %23, 1
  %31 = icmp eq i64 %30, %9
  br i1 %31, label %32, label %20

32:                                               ; preds = %20, %15
  %33 = phi i32 [ %16, %15 ], [ %28, %20 ]
  %34 = icmp eq i32 %33, 0
  br i1 %34, label %65, label %68

35:                                               ; preds = %35, %11
  %36 = phi i64 [ 0, %11 ], [ %62, %35 ]
  %37 = phi i32 [ 0, %11 ], [ %61, %35 ]
  %38 = phi i64 [ 0, %11 ], [ %63, %35 ]
  %39 = getelementptr inbounds nuw i8, ptr %1, i64 %36
  %40 = load i8, ptr %39, align 1
  %41 = getelementptr inbounds nuw [16 x i8], ptr %3, i64 0, i64 %36
  store i8 %40, ptr %41, align 4
  %42 = icmp eq i8 %40, 98
  %43 = or disjoint i64 %36, 1
  %44 = getelementptr inbounds nuw i8, ptr %1, i64 %43
  %45 = load i8, ptr %44, align 1
  %46 = getelementptr inbounds nuw [16 x i8], ptr %3, i64 0, i64 %43
  store i8 %45, ptr %46, align 1
  %47 = icmp eq i8 %45, 98
  %48 = or disjoint i64 %36, 2
  %49 = getelementptr inbounds nuw i8, ptr %1, i64 %48
  %50 = load i8, ptr %49, align 1
  %51 = getelementptr inbounds nuw [16 x i8], ptr %3, i64 0, i64 %48
  store i8 %50, ptr %51, align 2
  %52 = icmp eq i8 %50, 98
  %53 = or disjoint i64 %36, 3
  %54 = getelementptr inbounds nuw i8, ptr %1, i64 %53
  %55 = load i8, ptr %54, align 1
  %56 = getelementptr inbounds nuw [16 x i8], ptr %3, i64 0, i64 %53
  store i8 %55, ptr %56, align 1
  %57 = icmp eq i8 %55, 98
  %58 = select i1 %57, i1 true, i1 %52
  %59 = select i1 %58, i1 true, i1 %47
  %60 = select i1 %59, i1 true, i1 %42
  %61 = select i1 %60, i32 1, i32 %37
  %62 = add nuw nsw i64 %36, 4
  %63 = add i64 %38, 4
  %64 = icmp eq i64 %63, %12
  br i1 %64, label %15, label %35

65:                                               ; preds = %6, %32
  %66 = add nuw nsw i64 %4, 1
  %67 = getelementptr inbounds nuw [16 x i8], ptr %3, i64 0, i64 %4
  store i8 98, ptr %67, align 1
  br label %68

68:                                               ; preds = %65, %32
  %69 = phi i64 [ %4, %32 ], [ %66, %65 ]
  %70 = getelementptr inbounds nuw [16 x i8], ptr %3, i64 0, i64 %69
  store i8 0, ptr %70, align 1
  %71 = call ptr @__ucrt_fopen(ptr noundef %0, ptr noundef nonnull %3) #10
  br label %72

72:                                               ; preds = %68, %13
  %73 = phi ptr [ null, %13 ], [ %71, %68 ]
  call void @llvm.lifetime.end.p0(i64 16, ptr nonnull %3) #11
  ret ptr %73
}

declare dso_local i64 @strlen(ptr noundef) local_unnamed_addr #1

declare dso_local ptr @__ucrt_fopen(ptr noundef, ptr noundef) local_unnamed_addr #1

define dso_local range(i32 0, 12) i32 @pthread_key_create(ptr noundef writeonly captures(none) initializes((0, 8)) %0, ptr noundef %1) local_unnamed_addr #0 {
  %3 = tail call i32 @FlsAlloc(ptr noundef %1) #10
  %4 = zext i32 %3 to i64
  store i64 %4, ptr %0, align 8
  %5 = icmp eq i32 %3, -1
  %6 = select i1 %5, i32 11, i32 0
  ret i32 %6
}

declare dso_local i32 @FlsAlloc(ptr noundef) local_unnamed_addr #1

define dso_local ptr @pthread_getspecific(i64 noundef %0) local_unnamed_addr #0 {
  %2 = trunc i64 %0 to i32
  %3 = tail call ptr @FlsGetValue(i32 noundef %2) #10
  ret ptr %3
}

declare dso_local ptr @FlsGetValue(i32 noundef) local_unnamed_addr #1

define dso_local range(i32 0, 23) i32 @pthread_setspecific(i64 noundef %0, ptr noundef %1) local_unnamed_addr #0 {
  %3 = trunc i64 %0 to i32
  %4 = tail call i32 @FlsSetValue(i32 noundef %3, ptr noundef %1) #10
  %5 = icmp eq i32 %4, 0
  %6 = select i1 %5, i32 22, i32 0
  ret i32 %6
}

declare dso_local i32 @FlsSetValue(i32 noundef, ptr noundef) local_unnamed_addr #1

define dso_local range(i32 0, 13) i32 @pthread_create(ptr noundef writeonly captures(none) %0, ptr noundef readnone captures(none) %1, ptr noundef %2, ptr noundef %3) local_unnamed_addr #0 {
  %5 = tail call ptr @malloc(i64 noundef 32) #10
  %6 = icmp eq ptr %5, null
  br i1 %6, label %16, label %7

7:                                                ; preds = %4
  store ptr %2, ptr %5, align 8
  %8 = getelementptr inbounds nuw i8, ptr %5, i64 8
  store ptr %3, ptr %8, align 8
  %9 = getelementptr inbounds nuw i8, ptr %5, i64 16
  store ptr null, ptr %9, align 8
  %10 = tail call ptr @CreateThread(ptr noundef null, i64 noundef 0, ptr noundef nonnull @thread_main, ptr noundef nonnull %5, i32 noundef 0, ptr noundef null) #10
  %11 = getelementptr inbounds nuw i8, ptr %5, i64 24
  store ptr %10, ptr %11, align 8
  %12 = icmp eq ptr %10, null
  br i1 %12, label %13, label %14

13:                                               ; preds = %7
  tail call void @free(ptr noundef nonnull %5) #10
  br label %16

14:                                               ; preds = %7
  %15 = ptrtoint ptr %5 to i64
  store i64 %15, ptr %0, align 8
  br label %16

16:                                               ; preds = %4, %14, %13
  %17 = phi i32 [ 0, %14 ], [ 11, %13 ], [ 12, %4 ]
  ret i32 %17
}

declare dso_local ptr @malloc(i64 noundef) local_unnamed_addr #1

declare dso_local ptr @CreateThread(ptr noundef, i64 noundef, ptr noundef, ptr noundef, i32 noundef, ptr noundef) local_unnamed_addr #1

define internal noundef i32 @thread_main(ptr noundef captures(none) initializes((16, 24)) %0) #0 {
  %2 = load ptr, ptr %0, align 8
  %3 = getelementptr inbounds nuw i8, ptr %0, i64 8
  %4 = load ptr, ptr %3, align 8
  %5 = tail call ptr %2(ptr noundef %4) #10
  %6 = getelementptr inbounds nuw i8, ptr %0, i64 16
  store ptr %5, ptr %6, align 8
  ret i32 0
}

declare dso_local void @free(ptr noundef) local_unnamed_addr #1

define dso_local noundef i32 @pthread_join(i64 noundef %0, ptr noundef writeonly captures(address_is_null) %1) local_unnamed_addr #0 {
  %3 = inttoptr i64 %0 to ptr
  %4 = getelementptr inbounds nuw i8, ptr %3, i64 24
  %5 = load ptr, ptr %4, align 8
  %6 = tail call i32 @WaitForSingleObject(ptr noundef %5, i32 noundef -1) #10
  %7 = load ptr, ptr %4, align 8
  %8 = tail call i32 @CloseHandle(ptr noundef %7) #10
  %9 = icmp eq ptr %1, null
  br i1 %9, label %13, label %10

10:                                               ; preds = %2
  %11 = getelementptr inbounds nuw i8, ptr %3, i64 16
  %12 = load ptr, ptr %11, align 8
  store ptr %12, ptr %1, align 8
  br label %13

13:                                               ; preds = %10, %2
  tail call void @free(ptr noundef nonnull %3) #10
  ret i32 0
}

declare dso_local i32 @WaitForSingleObject(ptr noundef, i32 noundef) local_unnamed_addr #1

declare dso_local i32 @CloseHandle(ptr noundef) local_unnamed_addr #1

define dso_local range(i32 -1, 1) i32 @stat(ptr noundef %0, ptr noundef %1) local_unnamed_addr #0 {
  %3 = alloca [1040 x i8], align 16
  %4 = alloca %struct.ucrt_stat64, align 8
  call void @llvm.lifetime.start.p0(i64 1040, ptr nonnull %3) #11
  call void @llvm.lifetime.start.p0(i64 56, ptr nonnull %4) #11
  %5 = tail call i64 @strlen(ptr noundef %0) #10
  %6 = add i64 %5, 1
  %7 = icmp ugt i64 %6, 1040
  br i1 %7, label %24, label %8

8:                                                ; preds = %2
  %9 = call ptr @memcpy(ptr noundef nonnull %3, ptr noundef %0, i64 noundef %6) #10
  %10 = icmp ugt i64 %5, 1
  br i1 %10, label %11, label %26

11:                                               ; preds = %8, %20
  %12 = phi i64 [ %21, %20 ], [ %5, %8 ]
  %13 = getelementptr i8, ptr %3, i64 %12
  %14 = getelementptr i8, ptr %13, i64 -1
  %15 = load i8, ptr %14, align 1
  switch i8 %15, label %26 [
    i8 47, label %16
    i8 92, label %16
  ]

16:                                               ; preds = %11, %11
  %17 = getelementptr i8, ptr %13, i64 -2
  %18 = load i8, ptr %17, align 1
  %19 = icmp eq i8 %18, 58
  br i1 %19, label %26, label %20

20:                                               ; preds = %16
  %21 = add i64 %12, -1
  %22 = getelementptr inbounds nuw i8, ptr %3, i64 %21
  store i8 0, ptr %22, align 1
  %23 = icmp ugt i64 %21, 1
  br i1 %23, label %11, label %26

24:                                               ; preds = %2
  %25 = tail call ptr @_errno() #10
  store i32 2, ptr %25, align 4
  br label %65

26:                                               ; preds = %16, %20, %11, %8
  %27 = call i32 @_stat64(ptr noundef nonnull %3, ptr noundef nonnull %4) #10
  %28 = icmp eq i32 %27, 0
  br i1 %28, label %29, label %65

29:                                               ; preds = %26
  %30 = call ptr @memset(ptr noundef %1, i32 noundef 0, i64 noundef 144) #10
  %31 = load i32, ptr %4, align 8
  %32 = zext i32 %31 to i64
  store i64 %32, ptr %1, align 8
  %33 = getelementptr inbounds nuw i8, ptr %4, i64 4
  %34 = load i16, ptr %33, align 4
  %35 = zext i16 %34 to i64
  %36 = getelementptr inbounds nuw i8, ptr %1, i64 8
  store i64 %35, ptr %36, align 8
  %37 = getelementptr inbounds nuw i8, ptr %4, i64 8
  %38 = load i16, ptr %37, align 8
  %39 = sext i16 %38 to i64
  %40 = getelementptr inbounds nuw i8, ptr %1, i64 16
  store i64 %39, ptr %40, align 8
  %41 = getelementptr inbounds nuw i8, ptr %4, i64 6
  %42 = load i16, ptr %41, align 2
  %43 = zext i16 %42 to i32
  %44 = getelementptr inbounds nuw i8, ptr %1, i64 24
  store i32 %43, ptr %44, align 8
  %45 = getelementptr inbounds nuw i8, ptr %4, i64 16
  %46 = load i32, ptr %45, align 8
  %47 = zext i32 %46 to i64
  %48 = getelementptr inbounds nuw i8, ptr %1, i64 40
  store i64 %47, ptr %48, align 8
  %49 = getelementptr inbounds nuw i8, ptr %4, i64 24
  %50 = load i64, ptr %49, align 8
  %51 = getelementptr inbounds nuw i8, ptr %1, i64 48
  store i64 %50, ptr %51, align 8
  %52 = getelementptr inbounds nuw i8, ptr %1, i64 56
  store i64 4096, ptr %52, align 8
  %53 = add nsw i64 %50, 511
  %54 = sdiv i64 %53, 512
  %55 = getelementptr inbounds nuw i8, ptr %1, i64 64
  store i64 %54, ptr %55, align 8
  %56 = getelementptr inbounds nuw i8, ptr %4, i64 32
  %57 = load i64, ptr %56, align 8
  %58 = getelementptr inbounds nuw i8, ptr %1, i64 72
  store i64 %57, ptr %58, align 8
  %59 = getelementptr inbounds nuw i8, ptr %4, i64 40
  %60 = load i64, ptr %59, align 8
  %61 = getelementptr inbounds nuw i8, ptr %1, i64 88
  store i64 %60, ptr %61, align 8
  %62 = getelementptr inbounds nuw i8, ptr %4, i64 48
  %63 = load i64, ptr %62, align 8
  %64 = getelementptr inbounds nuw i8, ptr %1, i64 104
  store i64 %63, ptr %64, align 8
  br label %65

65:                                               ; preds = %26, %29, %24
  %66 = phi i32 [ 0, %29 ], [ -1, %24 ], [ -1, %26 ]
  call void @llvm.lifetime.end.p0(i64 56, ptr nonnull %4) #11
  call void @llvm.lifetime.end.p0(i64 1040, ptr nonnull %3) #11
  ret i32 %66
}

declare dso_local i32 @_stat64(ptr noundef, ptr noundef) local_unnamed_addr #1

define dso_local range(i32 -1, 1) i32 @lstat(ptr noundef %0, ptr noundef %1) local_unnamed_addr #0 {
  %3 = tail call i32 @stat(ptr noundef %0, ptr noundef %1) #12
  ret i32 %3
}

define dso_local range(i32 -1, 1) i32 @fstat(i32 noundef %0, ptr noundef %1) local_unnamed_addr #0 {
  %3 = alloca %struct.ucrt_stat64, align 8
  call void @llvm.lifetime.start.p0(i64 56, ptr nonnull %3) #11
  %4 = call i32 @_fstat64(i32 noundef %0, ptr noundef nonnull %3) #10
  %5 = icmp eq i32 %4, 0
  br i1 %5, label %6, label %42

6:                                                ; preds = %2
  %7 = call ptr @memset(ptr noundef %1, i32 noundef 0, i64 noundef 144) #10
  %8 = load i32, ptr %3, align 8
  %9 = zext i32 %8 to i64
  store i64 %9, ptr %1, align 8
  %10 = getelementptr inbounds nuw i8, ptr %3, i64 4
  %11 = load i16, ptr %10, align 4
  %12 = zext i16 %11 to i64
  %13 = getelementptr inbounds nuw i8, ptr %1, i64 8
  store i64 %12, ptr %13, align 8
  %14 = getelementptr inbounds nuw i8, ptr %3, i64 8
  %15 = load i16, ptr %14, align 8
  %16 = sext i16 %15 to i64
  %17 = getelementptr inbounds nuw i8, ptr %1, i64 16
  store i64 %16, ptr %17, align 8
  %18 = getelementptr inbounds nuw i8, ptr %3, i64 6
  %19 = load i16, ptr %18, align 2
  %20 = zext i16 %19 to i32
  %21 = getelementptr inbounds nuw i8, ptr %1, i64 24
  store i32 %20, ptr %21, align 8
  %22 = getelementptr inbounds nuw i8, ptr %3, i64 16
  %23 = load i32, ptr %22, align 8
  %24 = zext i32 %23 to i64
  %25 = getelementptr inbounds nuw i8, ptr %1, i64 40
  store i64 %24, ptr %25, align 8
  %26 = getelementptr inbounds nuw i8, ptr %3, i64 24
  %27 = load i64, ptr %26, align 8
  %28 = getelementptr inbounds nuw i8, ptr %1, i64 48
  store i64 %27, ptr %28, align 8
  %29 = getelementptr inbounds nuw i8, ptr %1, i64 56
  store i64 4096, ptr %29, align 8
  %30 = add nsw i64 %27, 511
  %31 = sdiv i64 %30, 512
  %32 = getelementptr inbounds nuw i8, ptr %1, i64 64
  store i64 %31, ptr %32, align 8
  %33 = getelementptr inbounds nuw i8, ptr %3, i64 32
  %34 = load i64, ptr %33, align 8
  %35 = getelementptr inbounds nuw i8, ptr %1, i64 72
  store i64 %34, ptr %35, align 8
  %36 = getelementptr inbounds nuw i8, ptr %3, i64 40
  %37 = load i64, ptr %36, align 8
  %38 = getelementptr inbounds nuw i8, ptr %1, i64 88
  store i64 %37, ptr %38, align 8
  %39 = getelementptr inbounds nuw i8, ptr %3, i64 48
  %40 = load i64, ptr %39, align 8
  %41 = getelementptr inbounds nuw i8, ptr %1, i64 104
  store i64 %40, ptr %41, align 8
  br label %42

42:                                               ; preds = %2, %6
  %43 = phi i32 [ 0, %6 ], [ -1, %2 ]
  call void @llvm.lifetime.end.p0(i64 56, ptr nonnull %3) #11
  ret i32 %43
}

declare dso_local i32 @_fstat64(i32 noundef, ptr noundef) local_unnamed_addr #1

define dso_local i32 @open(ptr noundef %0, i32 noundef %1, ...) local_unnamed_addr #0 {
  %3 = alloca ptr, align 8
  %4 = and i32 %1, 64
  %5 = icmp eq i32 %4, 0
  br i1 %5, label %10, label %6

6:                                                ; preds = %2
  call void @llvm.lifetime.start.p0(i64 8, ptr nonnull %3) #11
  call void @llvm.va_start.p0(ptr nonnull %3)
  %7 = load ptr, ptr %3, align 8
  %8 = getelementptr inbounds nuw i8, ptr %7, i64 8
  store ptr %8, ptr %3, align 8
  %9 = load i32, ptr %7, align 8
  call void @llvm.va_end.p0(ptr nonnull %3)
  call void @llvm.lifetime.end.p0(i64 8, ptr nonnull %3) #11
  br label %10

10:                                               ; preds = %6, %2
  %11 = phi i32 [ 33024, %6 ], [ 32768, %2 ]
  %12 = phi i32 [ %9, %6 ], [ 0, %2 ]
  %13 = and i32 %12, 292
  %14 = icmp eq i32 %13, 0
  %15 = select i1 %14, i32 0, i32 256
  %16 = and i32 %12, 146
  %17 = icmp eq i32 %16, 0
  %18 = select i1 %17, i32 0, i32 128
  %19 = or disjoint i32 %15, %18
  %20 = shl i32 %1, 3
  %21 = and i32 %20, 1024
  %22 = lshr i32 %1, 7
  %23 = and i32 %22, 8
  %24 = lshr i32 %1, 12
  %25 = and i32 %24, 128
  %26 = and i32 %1, 515
  %27 = or disjoint i32 %21, %26
  %28 = or disjoint i32 %27, %23
  %29 = or disjoint i32 %28, %25
  %30 = or disjoint i32 %29, %11
  %31 = call i32 @_open(ptr noundef %0, i32 noundef %30, i32 noundef %19) #10
  ret i32 %31
}

declare dso_local i32 @_open(ptr noundef, i32 noundef, i32 noundef) local_unnamed_addr #1

define dso_local i32 @openat(i32 noundef %0, ptr noundef %1, i32 noundef %2, ...) local_unnamed_addr #0 {
  %4 = alloca ptr, align 8
  %5 = and i32 %2, 64
  %6 = icmp eq i32 %5, 0
  br i1 %6, label %11, label %7

7:                                                ; preds = %3
  call void @llvm.lifetime.start.p0(i64 8, ptr nonnull %4) #11
  call void @llvm.va_start.p0(ptr nonnull %4)
  %8 = load ptr, ptr %4, align 8
  %9 = getelementptr inbounds nuw i8, ptr %8, i64 8
  store ptr %9, ptr %4, align 8
  %10 = load i32, ptr %8, align 8
  call void @llvm.va_end.p0(ptr nonnull %4)
  call void @llvm.lifetime.end.p0(i64 8, ptr nonnull %4) #11
  br label %11

11:                                               ; preds = %7, %3
  %12 = phi i32 [ %10, %7 ], [ 0, %3 ]
  %13 = icmp eq i32 %0, -100
  br i1 %13, label %16, label %14

14:                                               ; preds = %11
  %15 = call ptr @_errno() #10
  store i32 38, ptr %15, align 4
  br label %37

16:                                               ; preds = %11
  %17 = and i32 %12, 292
  %18 = icmp eq i32 %17, 0
  %19 = select i1 %18, i32 0, i32 256
  %20 = and i32 %12, 146
  %21 = icmp eq i32 %20, 0
  %22 = select i1 %21, i32 0, i32 128
  %23 = or disjoint i32 %19, %22
  %24 = select i1 %6, i32 32768, i32 33024
  %25 = shl i32 %2, 3
  %26 = and i32 %25, 1024
  %27 = lshr i32 %2, 7
  %28 = and i32 %27, 8
  %29 = lshr i32 %2, 12
  %30 = and i32 %29, 128
  %31 = and i32 %2, 515
  %32 = or disjoint i32 %26, %31
  %33 = or disjoint i32 %32, %28
  %34 = or disjoint i32 %33, %30
  %35 = or disjoint i32 %34, %24
  %36 = call i32 @_open(ptr noundef %1, i32 noundef %35, i32 noundef %23) #10
  br label %37

37:                                               ; preds = %16, %14
  %38 = phi i32 [ -1, %14 ], [ %36, %16 ]
  ret i32 %38
}

define dso_local i32 @creat(ptr noundef %0, i32 noundef %1) local_unnamed_addr #0 {
  %3 = and i32 %1, 292
  %4 = icmp eq i32 %3, 0
  %5 = select i1 %4, i32 0, i32 256
  %6 = and i32 %1, 146
  %7 = icmp eq i32 %6, 0
  %8 = select i1 %7, i32 0, i32 128
  %9 = or disjoint i32 %5, %8
  %10 = tail call i32 @_open(ptr noundef %0, i32 noundef 33537, i32 noundef %9) #10
  ret i32 %10
}

define dso_local i32 @mkdir(ptr noundef %0, i32 noundef %1) local_unnamed_addr #0 {
  %3 = tail call i32 @_mkdir(ptr noundef %0) #10
  ret i32 %3
}

declare dso_local i32 @_mkdir(ptr noundef) local_unnamed_addr #1

define dso_local i32 @access(ptr noundef %0, i32 noundef %1) local_unnamed_addr #0 {
  %3 = and i32 %1, 6
  %4 = tail call i32 @_access(ptr noundef %0, i32 noundef %3) #10
  ret i32 %4
}

declare dso_local i32 @_access(ptr noundef, i32 noundef) local_unnamed_addr #1

define dso_local range(i32 -1, 1) i32 @rename(ptr noundef %0, ptr noundef %1) local_unnamed_addr #0 {
  %3 = tail call i32 @MultiByteToWideChar(i32 noundef 65001, i32 noundef 0, ptr noundef %0, i32 noundef -1, ptr noundef null, i32 noundef 0) #10
  %4 = icmp slt i32 %3, 1
  br i1 %4, label %5, label %7

5:                                                ; preds = %2
  %6 = tail call ptr @_errno() #10
  store i32 22, ptr %6, align 4
  br label %43

7:                                                ; preds = %2
  %8 = shl nuw i32 %3, 1
  %9 = zext i32 %8 to i64
  %10 = tail call ptr @malloc(i64 noundef %9) #10
  %11 = icmp eq ptr %10, null
  br i1 %11, label %12, label %14

12:                                               ; preds = %7
  %13 = tail call ptr @_errno() #10
  store i32 12, ptr %13, align 4
  br label %43

14:                                               ; preds = %7
  %15 = tail call i32 @MultiByteToWideChar(i32 noundef 65001, i32 noundef 0, ptr noundef %0, i32 noundef -1, ptr noundef nonnull %10, i32 noundef %3) #10
  %16 = tail call i32 @MultiByteToWideChar(i32 noundef 65001, i32 noundef 0, ptr noundef %1, i32 noundef -1, ptr noundef null, i32 noundef 0) #10
  %17 = icmp slt i32 %16, 1
  br i1 %17, label %23, label %18

18:                                               ; preds = %14
  %19 = shl nuw i32 %16, 1
  %20 = zext i32 %19 to i64
  %21 = tail call ptr @malloc(i64 noundef %20) #10
  %22 = icmp eq ptr %21, null
  br i1 %22, label %23, label %26

23:                                               ; preds = %18, %14
  %24 = phi i32 [ 22, %14 ], [ 12, %18 ]
  %25 = tail call ptr @_errno() #10
  store i32 %24, ptr %25, align 4
  tail call void @free(ptr noundef nonnull %10) #10
  br label %43

26:                                               ; preds = %18
  %27 = tail call i32 @MultiByteToWideChar(i32 noundef 65001, i32 noundef 0, ptr noundef %1, i32 noundef -1, ptr noundef nonnull %21, i32 noundef %16) #10
  %28 = tail call i32 @MoveFileExW(ptr noundef nonnull %10, ptr noundef nonnull %21, i32 noundef 3) #10
  %29 = icmp eq i32 %28, 0
  br i1 %29, label %30, label %41

30:                                               ; preds = %26
  %31 = tail call i32 @GetLastError() #10
  switch i32 %31, label %37 [
    i32 2, label %38
    i32 3, label %38
    i32 15, label %38
    i32 53, label %38
    i32 67, label %38
    i32 123, label %38
    i32 161, label %38
    i32 5, label %32
    i32 19, label %32
    i32 32, label %32
    i32 33, label %32
    i32 108, label %32
    i32 8, label %33
    i32 14, label %33
    i32 80, label %34
    i32 183, label %34
    i32 267, label %35
    i32 87, label %36
  ]

32:                                               ; preds = %30, %30, %30, %30, %30
  br label %38

33:                                               ; preds = %30, %30
  br label %38

34:                                               ; preds = %30, %30
  br label %38

35:                                               ; preds = %30
  br label %38

36:                                               ; preds = %30
  br label %38

37:                                               ; preds = %30
  br label %38

38:                                               ; preds = %30, %30, %30, %30, %30, %30, %30, %32, %33, %34, %35, %36, %37
  %39 = phi i32 [ 5, %37 ], [ 13, %32 ], [ 12, %33 ], [ 17, %34 ], [ 20, %35 ], [ 22, %36 ], [ 2, %30 ], [ 2, %30 ], [ 2, %30 ], [ 2, %30 ], [ 2, %30 ], [ 2, %30 ], [ 2, %30 ]
  %40 = tail call ptr @_errno() #10
  store i32 %39, ptr %40, align 4
  br label %41

41:                                               ; preds = %38, %26
  tail call void @free(ptr noundef nonnull %10) #10
  tail call void @free(ptr noundef nonnull %21) #10
  %42 = sext i1 %29 to i32
  br label %43

43:                                               ; preds = %12, %5, %23, %41
  %44 = phi i32 [ %42, %41 ], [ -1, %23 ], [ -1, %5 ], [ -1, %12 ]
  ret i32 %44
}

declare dso_local i32 @MoveFileExW(ptr noundef, ptr noundef, i32 noundef) local_unnamed_addr #1

declare dso_local i32 @GetLastError() local_unnamed_addr #1

define dso_local range(i32 -1, 1) i32 @renameat(i32 noundef %0, ptr noundef %1, i32 noundef %2, ptr noundef %3) local_unnamed_addr #0 {
  %5 = icmp ne i32 %0, -100
  %6 = icmp ne i32 %2, -100
  %7 = or i1 %5, %6
  br i1 %7, label %8, label %10

8:                                                ; preds = %4
  %9 = tail call ptr @_errno() #10
  store i32 38, ptr %9, align 4
  br label %12

10:                                               ; preds = %4
  %11 = tail call i32 @rename(ptr noundef %1, ptr noundef %3) #12
  br label %12

12:                                               ; preds = %10, %8
  %13 = phi i32 [ -1, %8 ], [ %11, %10 ]
  ret i32 %13
}

define dso_local ptr @realpath(ptr noundef %0, ptr noundef %1) local_unnamed_addr #0 {
  %3 = alloca %struct.ucrt_stat64, align 8
  %4 = alloca [1040 x i8], align 16
  call void @llvm.lifetime.start.p0(i64 56, ptr nonnull %3) #11
  call void @llvm.lifetime.start.p0(i64 1040, ptr nonnull %4) #11
  %5 = tail call i64 @strlen(ptr noundef %0) #10
  %6 = add i64 %5, 1
  %7 = icmp ugt i64 %6, 1040
  br i1 %7, label %47, label %8

8:                                                ; preds = %2
  %9 = call ptr @memcpy(ptr noundef nonnull %4, ptr noundef %0, i64 noundef %6) #10
  %10 = icmp ugt i64 %5, 1
  br i1 %10, label %11, label %24

11:                                               ; preds = %8, %20
  %12 = phi i64 [ %21, %20 ], [ %5, %8 ]
  %13 = getelementptr i8, ptr %4, i64 %12
  %14 = getelementptr i8, ptr %13, i64 -1
  %15 = load i8, ptr %14, align 1
  switch i8 %15, label %24 [
    i8 47, label %16
    i8 92, label %16
  ]

16:                                               ; preds = %11, %11
  %17 = getelementptr i8, ptr %13, i64 -2
  %18 = load i8, ptr %17, align 1
  %19 = icmp eq i8 %18, 58
  br i1 %19, label %24, label %20

20:                                               ; preds = %16
  %21 = add i64 %12, -1
  %22 = getelementptr inbounds nuw i8, ptr %4, i64 %21
  store i8 0, ptr %22, align 1
  %23 = icmp ugt i64 %21, 1
  br i1 %23, label %11, label %24

24:                                               ; preds = %16, %20, %11, %8
  %25 = call i32 @_stat64(ptr noundef nonnull %4, ptr noundef nonnull %3) #10
  %26 = icmp eq i32 %25, 0
  br i1 %26, label %27, label %47

27:                                               ; preds = %24
  %28 = icmp eq ptr %1, null
  br i1 %28, label %29, label %35

29:                                               ; preds = %27
  %30 = call ptr @malloc(i64 noundef 4096) #10
  %31 = icmp eq ptr %30, null
  br i1 %31, label %47, label %32

32:                                               ; preds = %29
  %33 = call ptr @_fullpath(ptr noundef nonnull %30, ptr noundef nonnull %4, i64 noundef 4096) #10
  %34 = icmp eq ptr %33, null
  br i1 %34, label %38, label %39

35:                                               ; preds = %27
  %36 = call ptr @_fullpath(ptr noundef nonnull %1, ptr noundef nonnull %4, i64 noundef 4096) #10
  %37 = icmp eq ptr %36, null
  br i1 %37, label %47, label %39

38:                                               ; preds = %32
  call void @free(ptr noundef nonnull %30) #10
  br label %47

39:                                               ; preds = %35, %32
  %40 = phi ptr [ %1, %35 ], [ %30, %32 ]
  br label %41

41:                                               ; preds = %45, %39
  %42 = phi ptr [ %40, %39 ], [ %46, %45 ]
  %43 = load i8, ptr %42, align 1
  switch i8 %43, label %45 [
    i8 0, label %50
    i8 92, label %44
  ]

44:                                               ; preds = %41
  store i8 47, ptr %42, align 1
  br label %45

45:                                               ; preds = %44, %41
  %46 = getelementptr inbounds nuw i8, ptr %42, i64 1
  br label %41

47:                                               ; preds = %38, %35, %29, %24, %2
  %48 = phi i32 [ 2, %2 ], [ 2, %24 ], [ 12, %29 ], [ 34, %35 ], [ 34, %38 ]
  %49 = call ptr @_errno() #10
  store i32 %48, ptr %49, align 4
  br label %50

50:                                               ; preds = %41, %47
  %51 = phi ptr [ null, %47 ], [ %40, %41 ]
  call void @llvm.lifetime.end.p0(i64 1040, ptr nonnull %4) #11
  call void @llvm.lifetime.end.p0(i64 56, ptr nonnull %3) #11
  ret ptr %51
}

declare dso_local ptr @_fullpath(ptr noundef, ptr noundef, i64 noundef) local_unnamed_addr #1

define dso_local ptr @getcwd(ptr noundef %0, i64 noundef %1) local_unnamed_addr #0 {
  %3 = tail call i64 @llvm.umin.i64(i64 %1, i64 2147483647)
  %4 = trunc nuw nsw i64 %3 to i32
  %5 = tail call ptr @_getcwd(ptr noundef %0, i32 noundef %4) #10
  %6 = icmp eq ptr %5, null
  br i1 %6, label %13, label %7

7:                                                ; preds = %2, %11
  %8 = phi ptr [ %12, %11 ], [ %5, %2 ]
  %9 = load i8, ptr %8, align 1
  switch i8 %9, label %11 [
    i8 0, label %13
    i8 92, label %10
  ]

10:                                               ; preds = %7
  store i8 47, ptr %8, align 1
  br label %11

11:                                               ; preds = %10, %7
  %12 = getelementptr inbounds nuw i8, ptr %8, i64 1
  br label %7

13:                                               ; preds = %7, %2
  ret ptr %5
}

declare dso_local ptr @_getcwd(ptr noundef, i32 noundef) local_unnamed_addr #1

define dso_local noundef i64 @readlink(ptr noundef readnone captures(none) %0, ptr noundef readnone captures(none) %1, i64 noundef %2) local_unnamed_addr #0 {
  %4 = tail call ptr @_errno() #10
  store i32 22, ptr %4, align 4
  ret i64 -1
}

define dso_local ptr @opendir(ptr noundef %0) local_unnamed_addr #0 {
  %2 = alloca %struct.ucrt_stat64, align 8
  %3 = alloca [1044 x i8], align 16
  call void @llvm.lifetime.start.p0(i64 56, ptr nonnull %2) #11
  call void @llvm.lifetime.start.p0(i64 1044, ptr nonnull %3) #11
  %4 = tail call i64 @strlen(ptr noundef %0) #10
  %5 = add i64 %4, 1
  %6 = icmp ugt i64 %5, 1040
  br i1 %6, label %26, label %7

7:                                                ; preds = %1
  %8 = call ptr @memcpy(ptr noundef nonnull %3, ptr noundef %0, i64 noundef %5) #10
  %9 = icmp ugt i64 %4, 1
  br i1 %9, label %10, label %23

10:                                               ; preds = %7, %19
  %11 = phi i64 [ %20, %19 ], [ %4, %7 ]
  %12 = getelementptr i8, ptr %3, i64 %11
  %13 = getelementptr i8, ptr %12, i64 -1
  %14 = load i8, ptr %13, align 1
  switch i8 %14, label %23 [
    i8 47, label %15
    i8 92, label %15
  ]

15:                                               ; preds = %10, %10
  %16 = getelementptr i8, ptr %12, i64 -2
  %17 = load i8, ptr %16, align 1
  %18 = icmp eq i8 %17, 58
  br i1 %18, label %23, label %19

19:                                               ; preds = %15
  %20 = add i64 %11, -1
  %21 = getelementptr inbounds nuw i8, ptr %3, i64 %20
  store i8 0, ptr %21, align 1
  %22 = icmp ugt i64 %20, 1
  br i1 %22, label %10, label %23

23:                                               ; preds = %15, %19, %10, %7
  %24 = call i32 @_stat64(ptr noundef nonnull %3, ptr noundef nonnull %2) #10
  %25 = icmp eq i32 %24, 0
  br i1 %25, label %28, label %26

26:                                               ; preds = %1, %23
  %27 = call ptr @_errno() #10
  store i32 2, ptr %27, align 4
  br label %64

28:                                               ; preds = %23
  %29 = getelementptr inbounds nuw i8, ptr %2, i64 6
  %30 = load i16, ptr %29, align 2
  %31 = and i16 %30, -4096
  %32 = icmp eq i16 %31, 16384
  br i1 %32, label %35, label %33

33:                                               ; preds = %28
  %34 = call ptr @_errno() #10
  store i32 20, ptr %34, align 4
  br label %64

35:                                               ; preds = %28
  %36 = call i64 @strlen(ptr noundef nonnull %3) #10
  %37 = add i64 %36, -1
  %38 = getelementptr inbounds nuw [1044 x i8], ptr %3, i64 0, i64 %37
  %39 = load i8, ptr %38, align 1
  switch i8 %39, label %40 [
    i8 47, label %43
    i8 92, label %43
  ]

40:                                               ; preds = %35
  %41 = add i64 %36, 1
  %42 = getelementptr inbounds nuw [1044 x i8], ptr %3, i64 0, i64 %36
  store i8 47, ptr %42, align 1
  br label %43

43:                                               ; preds = %35, %35, %40
  %44 = phi i64 [ %41, %40 ], [ %36, %35 ], [ %36, %35 ]
  %45 = add i64 %44, 1
  %46 = getelementptr inbounds nuw [1044 x i8], ptr %3, i64 0, i64 %44
  store i8 42, ptr %46, align 1
  %47 = getelementptr inbounds nuw [1044 x i8], ptr %3, i64 0, i64 %45
  store i8 0, ptr %47, align 1
  %48 = call ptr @malloc(i64 noundef 600) #10
  %49 = icmp eq ptr %48, null
  br i1 %49, label %50, label %52

50:                                               ; preds = %43
  %51 = call ptr @_errno() #10
  store i32 12, ptr %51, align 4
  br label %64

52:                                               ; preds = %43
  %53 = getelementptr inbounds nuw i8, ptr %48, i64 16
  %54 = call i64 @_findfirst64(ptr noundef nonnull %3, ptr noundef nonnull %53) #10
  store i64 %54, ptr %48, align 8
  %55 = icmp ne i64 %54, -1
  %56 = zext i1 %55 to i32
  %57 = getelementptr inbounds nuw i8, ptr %48, i64 8
  store i32 %56, ptr %57, align 8
  %58 = icmp eq i64 %54, -1
  br i1 %58, label %59, label %64

59:                                               ; preds = %52
  %60 = call ptr @_errno() #10
  %61 = load i32, ptr %60, align 4
  %62 = icmp eq i32 %61, 2
  br i1 %62, label %64, label %63

63:                                               ; preds = %59
  call void @free(ptr noundef nonnull %48) #10
  br label %64

64:                                               ; preds = %50, %63, %59, %52, %33, %26
  %65 = phi ptr [ null, %26 ], [ null, %33 ], [ null, %63 ], [ null, %50 ], [ %48, %59 ], [ %48, %52 ]
  call void @llvm.lifetime.end.p0(i64 1044, ptr nonnull %3) #11
  call void @llvm.lifetime.end.p0(i64 56, ptr nonnull %2) #11
  ret ptr %65
}

declare dso_local i64 @_findfirst64(ptr noundef, ptr noundef) local_unnamed_addr #1

define dso_local ptr @readdir(ptr noundef %0) local_unnamed_addr #0 {
  %2 = load i64, ptr %0, align 8
  %3 = icmp eq i64 %2, -1
  br i1 %3, label %33, label %4

4:                                                ; preds = %1
  %5 = getelementptr inbounds nuw i8, ptr %0, i64 8
  %6 = load i32, ptr %5, align 8
  %7 = icmp eq i32 %6, 0
  br i1 %7, label %8, label %17

8:                                                ; preds = %4
  %9 = tail call ptr @_errno() #10
  %10 = load i32, ptr %9, align 4
  %11 = getelementptr inbounds nuw i8, ptr %0, i64 16
  %12 = load i64, ptr %0, align 8
  %13 = tail call i32 @_findnext64(i64 noundef %12, ptr noundef nonnull %11) #10
  %14 = icmp eq i32 %13, 0
  br i1 %14, label %17, label %15

15:                                               ; preds = %8
  %16 = tail call ptr @_errno() #10
  store i32 %10, ptr %16, align 4
  br label %33

17:                                               ; preds = %8, %4
  store i32 0, ptr %5, align 8
  %18 = getelementptr inbounds nuw i8, ptr %0, i64 16
  %19 = getelementptr inbounds nuw i8, ptr %0, i64 56
  %20 = tail call i64 @strlen(ptr noundef nonnull %19) #10
  %21 = tail call i64 @llvm.umin.i64(i64 %20, i64 255)
  %22 = getelementptr inbounds nuw i8, ptr %0, i64 320
  %23 = getelementptr inbounds nuw i8, ptr %0, i64 339
  %24 = tail call ptr @memcpy(ptr noundef nonnull %23, ptr noundef nonnull %19, i64 noundef %21) #10
  %25 = getelementptr inbounds nuw [256 x i8], ptr %23, i64 0, i64 %21
  store i8 0, ptr %25, align 1
  store i64 1, ptr %22, align 8
  %26 = getelementptr inbounds nuw i8, ptr %0, i64 328
  store i64 0, ptr %26, align 8
  %27 = getelementptr inbounds nuw i8, ptr %0, i64 336
  store i16 280, ptr %27, align 8
  %28 = load i32, ptr %18, align 8
  %29 = and i32 %28, 16
  %30 = icmp eq i32 %29, 0
  %31 = select i1 %30, i8 8, i8 4
  %32 = getelementptr inbounds nuw i8, ptr %0, i64 338
  store i8 %31, ptr %32, align 2
  br label %33

33:                                               ; preds = %15, %1, %17
  %34 = phi ptr [ %22, %17 ], [ null, %15 ], [ null, %1 ]
  ret ptr %34
}

declare dso_local i32 @_findnext64(i64 noundef, ptr noundef) local_unnamed_addr #1

declare dso_local ptr @memcpy(ptr noundef, ptr noundef, i64 noundef) local_unnamed_addr #1

define dso_local noundef i32 @closedir(ptr noundef %0) local_unnamed_addr #0 {
  %2 = load i64, ptr %0, align 8
  %3 = icmp eq i64 %2, -1
  br i1 %3, label %6, label %4

4:                                                ; preds = %1
  %5 = tail call i32 @_findclose(i64 noundef %2) #10
  br label %6

6:                                                ; preds = %4, %1
  tail call void @free(ptr noundef nonnull %0) #10
  ret i32 0
}

declare dso_local i32 @_findclose(i64 noundef) local_unnamed_addr #1

define dso_local range(i32 -1, 1) i32 @setenv(ptr noundef %0, ptr noundef %1, i32 noundef %2) local_unnamed_addr #0 {
  %4 = icmp eq i32 %2, 0
  br i1 %4, label %5, label %8

5:                                                ; preds = %3
  %6 = tail call ptr @getenv(ptr noundef %0) #10
  %7 = icmp eq ptr %6, null
  br i1 %7, label %8, label %13

8:                                                ; preds = %5, %3
  %9 = tail call i32 @_putenv_s(ptr noundef %0, ptr noundef %1) #10
  %10 = icmp eq i32 %9, 0
  br i1 %10, label %13, label %11

11:                                               ; preds = %8
  %12 = tail call ptr @_errno() #10
  store i32 22, ptr %12, align 4
  br label %13

13:                                               ; preds = %8, %5, %11
  %14 = phi i32 [ -1, %11 ], [ 0, %5 ], [ 0, %8 ]
  ret i32 %14
}

declare dso_local ptr @getenv(ptr noundef) local_unnamed_addr #1

declare dso_local i32 @_putenv_s(ptr noundef, ptr noundef) local_unnamed_addr #1

define dso_local range(i32 -1, 1) i32 @unsetenv(ptr noundef %0) local_unnamed_addr #0 {
  %2 = tail call i32 @_putenv_s(ptr noundef %0, ptr noundef nonnull @"??_C@_00CNPNBAHC@?$AA@") #10
  %3 = icmp eq i32 %2, 0
  br i1 %3, label %6, label %4

4:                                                ; preds = %1
  %5 = tail call ptr @_errno() #10
  store i32 22, ptr %5, align 4
  br label %6

6:                                                ; preds = %1, %4
  %7 = phi i32 [ -1, %4 ], [ 0, %1 ]
  ret i32 %7
}

define dso_local noundef i32 @getuid() local_unnamed_addr #4 {
  ret i32 0
}

define dso_local noundef i32 @geteuid() local_unnamed_addr #4 {
  ret i32 0
}

define dso_local noundef i32 @getgid() local_unnamed_addr #4 {
  ret i32 0
}

define dso_local noundef i32 @getegid() local_unnamed_addr #4 {
  ret i32 0
}

define dso_local range(i32 0, 35) i32 @getpwuid_r(i32 noundef %0, ptr noundef %1, ptr noundef %2, i64 noundef %3, ptr noundef writeonly captures(none) initializes((0, 8)) %4) local_unnamed_addr #0 {
  store ptr null, ptr %4, align 8
  %6 = icmp eq i32 %0, 0
  br i1 %6, label %7, label %9

7:                                                ; preds = %5
  %8 = tail call fastcc i32 @current_user(ptr noundef %1, ptr noundef %2, i64 noundef %3, ptr noundef nonnull %4) #12
  br label %9

9:                                                ; preds = %5, %7
  %10 = phi i32 [ %8, %7 ], [ 0, %5 ]
  ret i32 %10
}

define internal fastcc range(i32 0, 35) i32 @current_user(ptr noundef %0, ptr noundef %1, i64 noundef %2, ptr noundef writeonly captures(none) initializes((0, 8)) %3) unnamed_addr #0 {
  %5 = tail call ptr @getenv(ptr noundef nonnull @"??_C@_08JMMIJEMM@USERNAME?$AA@") #10
  %6 = tail call ptr @getenv(ptr noundef nonnull @"??_C@_0M@DPNKMMOG@USERPROFILE?$AA@") #10
  store ptr null, ptr %3, align 8
  %7 = icmp ne ptr %5, null
  %8 = icmp ne ptr %6, null
  %9 = select i1 %7, i1 %8, i1 false
  br i1 %9, label %10, label %37

10:                                               ; preds = %4
  %11 = tail call i64 @strlen(ptr noundef nonnull %5) #10
  %12 = add i64 %11, 1
  %13 = tail call i64 @strlen(ptr noundef nonnull %6) #10
  %14 = add i64 %13, 1
  %15 = add i64 %14, %12
  %16 = add i64 %15, 1
  %17 = icmp ugt i64 %16, %2
  br i1 %17, label %37, label %18

18:                                               ; preds = %10
  %19 = tail call ptr @memcpy(ptr noundef %1, ptr noundef nonnull %5, i64 noundef %12) #10
  %20 = getelementptr inbounds nuw i8, ptr %1, i64 %12
  %21 = tail call ptr @memcpy(ptr noundef %20, ptr noundef nonnull %6, i64 noundef %14) #10
  br label %22

22:                                               ; preds = %26, %18
  %23 = phi ptr [ %20, %18 ], [ %27, %26 ]
  %24 = load i8, ptr %23, align 1
  switch i8 %24, label %26 [
    i8 0, label %28
    i8 92, label %25
  ]

25:                                               ; preds = %22
  store i8 47, ptr %23, align 1
  br label %26

26:                                               ; preds = %25, %22
  %27 = getelementptr inbounds nuw i8, ptr %23, i64 1
  br label %22

28:                                               ; preds = %22
  %29 = getelementptr inbounds nuw i8, ptr %1, i64 %15
  store i8 0, ptr %29, align 1
  store ptr %1, ptr %0, align 8
  %30 = getelementptr inbounds nuw i8, ptr %20, i64 %14
  %31 = getelementptr inbounds nuw i8, ptr %0, i64 8
  store ptr %30, ptr %31, align 8
  %32 = getelementptr inbounds nuw i8, ptr %0, i64 16
  store i32 0, ptr %32, align 8
  %33 = getelementptr inbounds nuw i8, ptr %0, i64 20
  store i32 0, ptr %33, align 4
  %34 = getelementptr inbounds nuw i8, ptr %0, i64 24
  store ptr %30, ptr %34, align 8
  %35 = getelementptr inbounds nuw i8, ptr %0, i64 32
  store ptr %20, ptr %35, align 8
  %36 = getelementptr inbounds nuw i8, ptr %0, i64 40
  store ptr %30, ptr %36, align 8
  store ptr %0, ptr %3, align 8
  br label %37

37:                                               ; preds = %28, %10, %4
  %38 = phi i32 [ 0, %4 ], [ 0, %28 ], [ 34, %10 ]
  ret i32 %38
}

define dso_local range(i32 0, 35) i32 @getpwnam_r(ptr noundef %0, ptr noundef %1, ptr noundef %2, i64 noundef %3, ptr noundef writeonly captures(none) initializes((0, 8)) %4) local_unnamed_addr #0 {
  %6 = tail call ptr @getenv(ptr noundef nonnull @"??_C@_08JMMIJEMM@USERNAME?$AA@") #10
  store ptr null, ptr %4, align 8
  %7 = icmp eq ptr %6, null
  br i1 %7, label %18, label %8

8:                                                ; preds = %5
  %9 = tail call i64 @strlen(ptr noundef nonnull %6) #10
  %10 = tail call i64 @strlen(ptr noundef %0) #10
  %11 = icmp eq i64 %9, %10
  br i1 %11, label %12, label %18

12:                                               ; preds = %8
  %13 = tail call i64 @strlen(ptr noundef %0) #10
  %14 = tail call i32 @memcmp(ptr noundef nonnull %6, ptr noundef %0, i64 noundef %13) #10
  %15 = icmp eq i32 %14, 0
  br i1 %15, label %16, label %18

16:                                               ; preds = %12
  %17 = tail call fastcc i32 @current_user(ptr noundef %1, ptr noundef %2, i64 noundef %3, ptr noundef nonnull %4) #12
  br label %18

18:                                               ; preds = %5, %8, %12, %16
  %19 = phi i32 [ %17, %16 ], [ 0, %12 ], [ 0, %8 ], [ 0, %5 ]
  ret i32 %19
}

define dso_local range(i32 -1, 1) i32 @clock_gettime(i32 noundef %0, ptr noundef writeonly captures(none) %1) local_unnamed_addr #0 {
  %3 = alloca i64, align 8
  %4 = alloca i64, align 8
  %5 = alloca i64, align 8
  %6 = alloca i64, align 8
  %7 = alloca i64, align 8
  %8 = alloca i64, align 8
  %9 = alloca i64, align 8
  %10 = icmp eq i32 %0, 0
  br i1 %10, label %11, label %18

11:                                               ; preds = %2
  call void @llvm.lifetime.start.p0(i64 8, ptr nonnull %3) #11
  call void @GetSystemTimePreciseAsFileTime(ptr noundef nonnull %3) #10
  %12 = load i64, ptr %3, align 8
  %13 = add i64 %12, -116444736000000000
  %14 = udiv i64 %13, 10000000
  store i64 %14, ptr %1, align 8
  %15 = urem i64 %13, 10000000
  %16 = mul nuw nsw i64 %15, 100
  %17 = getelementptr inbounds nuw i8, ptr %1, i64 8
  store i64 %16, ptr %17, align 8
  call void @llvm.lifetime.end.p0(i64 8, ptr nonnull %3) #11
  br label %54

18:                                               ; preds = %2
  %19 = and i32 %0, -2
  %20 = icmp eq i32 %19, 2
  br i1 %20, label %21, label %44

21:                                               ; preds = %18
  %22 = icmp eq i32 %0, 2
  call void @llvm.lifetime.start.p0(i64 8, ptr nonnull %4) #11
  call void @llvm.lifetime.start.p0(i64 8, ptr nonnull %5) #11
  call void @llvm.lifetime.start.p0(i64 8, ptr nonnull %6) #11
  call void @llvm.lifetime.start.p0(i64 8, ptr nonnull %7) #11
  br i1 %22, label %23, label %26

23:                                               ; preds = %21
  %24 = tail call ptr @GetCurrentProcess() #10
  %25 = call i32 @GetProcessTimes(ptr noundef %24, ptr noundef nonnull %4, ptr noundef nonnull %5, ptr noundef nonnull %6, ptr noundef nonnull %7) #10
  br label %29

26:                                               ; preds = %21
  %27 = tail call ptr @GetCurrentThread() #10
  %28 = call i32 @GetThreadTimes(ptr noundef %27, ptr noundef nonnull %4, ptr noundef nonnull %5, ptr noundef nonnull %6, ptr noundef nonnull %7) #10
  br label %29

29:                                               ; preds = %26, %23
  %30 = phi i32 [ %25, %23 ], [ %28, %26 ]
  %31 = icmp eq i32 %30, 0
  br i1 %31, label %32, label %34

32:                                               ; preds = %29
  %33 = call ptr @_errno() #10
  store i32 22, ptr %33, align 4
  br label %42

34:                                               ; preds = %29
  %35 = load i64, ptr %6, align 8
  %36 = load i64, ptr %7, align 8
  %37 = add i64 %36, %35
  %38 = udiv i64 %37, 10000000
  store i64 %38, ptr %1, align 8
  %39 = urem i64 %37, 10000000
  %40 = mul nuw nsw i64 %39, 100
  %41 = getelementptr inbounds nuw i8, ptr %1, i64 8
  store i64 %40, ptr %41, align 8
  br label %42

42:                                               ; preds = %34, %32
  %43 = phi i32 [ 0, %34 ], [ -1, %32 ]
  call void @llvm.lifetime.end.p0(i64 8, ptr nonnull %7) #11
  call void @llvm.lifetime.end.p0(i64 8, ptr nonnull %6) #11
  call void @llvm.lifetime.end.p0(i64 8, ptr nonnull %5) #11
  call void @llvm.lifetime.end.p0(i64 8, ptr nonnull %4) #11
  br label %54

44:                                               ; preds = %18
  call void @llvm.lifetime.start.p0(i64 8, ptr nonnull %8) #11
  call void @llvm.lifetime.start.p0(i64 8, ptr nonnull %9) #11
  %45 = call i32 @QueryPerformanceCounter(ptr noundef nonnull %8) #10
  %46 = call i32 @QueryPerformanceFrequency(ptr noundef nonnull %9) #10
  %47 = load i64, ptr %8, align 8
  %48 = load i64, ptr %9, align 8
  %49 = sdiv i64 %47, %48
  store i64 %49, ptr %1, align 8
  %50 = srem i64 %47, %48
  %51 = mul nsw i64 %50, 1000000000
  %52 = sdiv i64 %51, %48
  %53 = getelementptr inbounds nuw i8, ptr %1, i64 8
  store i64 %52, ptr %53, align 8
  call void @llvm.lifetime.end.p0(i64 8, ptr nonnull %9) #11
  call void @llvm.lifetime.end.p0(i64 8, ptr nonnull %8) #11
  br label %54

54:                                               ; preds = %44, %42, %11
  %55 = phi i32 [ 0, %11 ], [ %43, %42 ], [ 0, %44 ]
  ret i32 %55
}

declare dso_local void @GetSystemTimePreciseAsFileTime(ptr noundef) local_unnamed_addr #1

declare dso_local i32 @GetProcessTimes(ptr noundef, ptr noundef, ptr noundef, ptr noundef, ptr noundef) local_unnamed_addr #1

declare dso_local ptr @GetCurrentProcess() local_unnamed_addr #1

declare dso_local i32 @GetThreadTimes(ptr noundef, ptr noundef, ptr noundef, ptr noundef, ptr noundef) local_unnamed_addr #1

declare dso_local ptr @GetCurrentThread() local_unnamed_addr #1

declare dso_local i32 @QueryPerformanceCounter(ptr noundef) local_unnamed_addr #1

declare dso_local i32 @QueryPerformanceFrequency(ptr noundef) local_unnamed_addr #1

define dso_local noundef i32 @clock_settime(i32 noundef %0, ptr noundef readnone captures(none) %1) local_unnamed_addr #0 {
  %3 = tail call ptr @_errno() #10
  store i32 1, ptr %3, align 4
  ret i32 -1
}

define dso_local noundef i32 @clock_getres(i32 noundef %0, ptr noundef writeonly captures(none) initializes((0, 16)) %1) local_unnamed_addr #5 {
  store i64 0, ptr %1, align 8
  %3 = getelementptr inbounds nuw i8, ptr %1, i64 8
  store i64 100, ptr %3, align 8
  ret i32 0
}

define dso_local range(i32 -1, 1) i32 @nanosleep(ptr noundef readonly captures(none) %0, ptr noundef writeonly captures(address_is_null) %1) local_unnamed_addr #0 {
  %3 = load i64, ptr %0, align 8
  %4 = icmp slt i64 %3, 0
  br i1 %4, label %9, label %5

5:                                                ; preds = %2
  %6 = getelementptr inbounds nuw i8, ptr %0, i64 8
  %7 = load i64, ptr %6, align 8
  %8 = icmp ugt i64 %7, 999999999
  br i1 %8, label %9, label %11

9:                                                ; preds = %5, %2
  %10 = tail call ptr @_errno() #10
  store i32 22, ptr %10, align 4
  br label %17

11:                                               ; preds = %5
  %12 = mul nuw nsw i64 %3, 1000000000
  %13 = add nuw nsw i64 %7, %12
  tail call fastcc void @sleep_ns(i64 noundef %13) #12
  %14 = icmp eq ptr %1, null
  br i1 %14, label %17, label %15

15:                                               ; preds = %11
  store i64 0, ptr %1, align 8
  %16 = getelementptr inbounds nuw i8, ptr %1, i64 8
  store i64 0, ptr %16, align 8
  br label %17

17:                                               ; preds = %11, %15, %9
  %18 = phi i32 [ -1, %9 ], [ 0, %15 ], [ 0, %11 ]
  ret i32 %18
}

define internal fastcc void @sleep_ns(i64 noundef %0) unnamed_addr #0 {
  %2 = alloca i64, align 8
  %3 = icmp slt i64 %0, 1
  br i1 %3, label %22, label %4

4:                                                ; preds = %1
  %5 = tail call ptr @CreateWaitableTimerExW(ptr noundef null, ptr noundef null, i32 noundef 2, i32 noundef 2031619) #10
  %6 = icmp eq ptr %5, null
  br i1 %6, label %18, label %7

7:                                                ; preds = %4
  call void @llvm.lifetime.start.p0(i64 8, ptr nonnull %2) #11
  %8 = add nuw nsw i64 %0, 99
  %9 = udiv i64 %8, 100
  %10 = sub nsw i64 0, %9
  store i64 %10, ptr %2, align 8
  %11 = call i32 @SetWaitableTimer(ptr noundef nonnull %5, ptr noundef nonnull %2, i32 noundef 0, ptr noundef null, ptr noundef null, i32 noundef 0) #10
  %12 = icmp eq i32 %11, 0
  br i1 %12, label %13, label %15

13:                                               ; preds = %7
  %14 = call i32 @CloseHandle(ptr noundef nonnull %5) #10
  call void @llvm.lifetime.end.p0(i64 8, ptr nonnull %2) #11
  br label %18

15:                                               ; preds = %7
  %16 = call i32 @WaitForSingleObject(ptr noundef nonnull %5, i32 noundef -1) #10
  %17 = call i32 @CloseHandle(ptr noundef nonnull %5) #10
  call void @llvm.lifetime.end.p0(i64 8, ptr nonnull %2) #11
  br label %22

18:                                               ; preds = %13, %4
  %19 = add nuw nsw i64 %0, 999999
  %20 = udiv i64 %19, 1000000
  %21 = trunc i64 %20 to i32
  call void @Sleep(i32 noundef %21) #10
  br label %22

22:                                               ; preds = %15, %18, %1
  ret void
}

define dso_local range(i32 0, 23) i32 @clock_nanosleep(i32 noundef %0, i32 noundef %1, ptr noundef readonly captures(none) %2, ptr noundef writeonly captures(address_is_null) %3) local_unnamed_addr #0 {
  %5 = alloca %struct.linux_timespec, align 8
  %6 = getelementptr inbounds nuw i8, ptr %2, i64 8
  %7 = load i64, ptr %6, align 8
  %8 = icmp ugt i64 %7, 999999999
  br i1 %8, label %28, label %9

9:                                                ; preds = %4
  %10 = load i64, ptr %2, align 8
  %11 = mul nsw i64 %10, 1000000000
  %12 = add nsw i64 %11, %7
  %13 = and i32 %1, 1
  %14 = icmp eq i32 %13, 0
  br i1 %14, label %23, label %15

15:                                               ; preds = %9
  call void @llvm.lifetime.start.p0(i64 16, ptr nonnull %5) #11
  %16 = call i32 @clock_gettime(i32 noundef %0, ptr noundef nonnull %5) #12
  %17 = load i64, ptr %5, align 8
  %18 = getelementptr inbounds nuw i8, ptr %5, i64 8
  %19 = load i64, ptr %18, align 8
  %20 = mul i64 %17, -1000000000
  %21 = sub i64 %12, %19
  %22 = add i64 %21, %20
  call void @llvm.lifetime.end.p0(i64 16, ptr nonnull %5) #11
  br label %23

23:                                               ; preds = %15, %9
  %24 = phi i64 [ %22, %15 ], [ %12, %9 ]
  tail call fastcc void @sleep_ns(i64 noundef %24) #12
  %25 = icmp eq ptr %3, null
  br i1 %25, label %28, label %26

26:                                               ; preds = %23
  store i64 0, ptr %3, align 8
  %27 = getelementptr inbounds nuw i8, ptr %3, i64 8
  store i64 0, ptr %27, align 8
  br label %28

28:                                               ; preds = %23, %26, %4
  %29 = phi i32 [ 22, %4 ], [ 0, %26 ], [ 0, %23 ]
  ret i32 %29
}

define dso_local noundef i32 @usleep(i32 noundef %0) local_unnamed_addr #0 {
  %2 = zext i32 %0 to i64
  %3 = mul nuw nsw i64 %2, 1000
  tail call fastcc void @sleep_ns(i64 noundef %3) #12
  ret i32 0
}

define dso_local noundef i32 @sleep(i32 noundef %0) local_unnamed_addr #0 {
  %2 = zext i32 %0 to i64
  %3 = mul nuw nsw i64 %2, 1000000000
  tail call fastcc void @sleep_ns(i64 noundef %3) #12
  ret i32 0
}

define dso_local noundef ptr @gmtime_r(ptr noundef %0, ptr noundef %1) local_unnamed_addr #0 {
  %3 = tail call i32 @_gmtime64_s(ptr noundef %1, ptr noundef %0) #10
  %4 = icmp eq i32 %3, 0
  br i1 %4, label %5, label %8

5:                                                ; preds = %2
  %6 = getelementptr inbounds nuw i8, ptr %1, i64 40
  store i64 0, ptr %6, align 8
  %7 = getelementptr inbounds nuw i8, ptr %1, i64 48
  store ptr @"??_C@_03JCIJEFNJ@UTC?$AA@", ptr %7, align 8
  br label %8

8:                                                ; preds = %2, %5
  %9 = phi ptr [ %1, %5 ], [ null, %2 ]
  ret ptr %9
}

declare dso_local i32 @_gmtime64_s(ptr noundef, ptr noundef) local_unnamed_addr #1

define dso_local noundef ptr @localtime_r(ptr noundef %0, ptr noundef %1) local_unnamed_addr #0 {
  %3 = alloca [9 x i32], align 16
  %4 = tail call i32 @_localtime64_s(ptr noundef %1, ptr noundef %0) #10
  %5 = icmp eq i32 %4, 0
  br i1 %5, label %6, label %13

6:                                                ; preds = %2
  call void @llvm.lifetime.start.p0(i64 36, ptr nonnull %3) #11
  %7 = call ptr @memcpy(ptr noundef nonnull %3, ptr noundef %1, i64 noundef 36) #10
  %8 = call i64 @_mkgmtime64(ptr noundef nonnull %3) #10
  %9 = load i64, ptr %0, align 8
  %10 = sub nsw i64 %8, %9
  %11 = getelementptr inbounds nuw i8, ptr %1, i64 40
  store i64 %10, ptr %11, align 8
  %12 = getelementptr inbounds nuw i8, ptr %1, i64 48
  store ptr @"??_C@_00CNPNBAHC@?$AA@", ptr %12, align 8
  call void @llvm.lifetime.end.p0(i64 36, ptr nonnull %3) #11
  br label %13

13:                                               ; preds = %2, %6
  %14 = phi ptr [ %1, %6 ], [ null, %2 ]
  ret ptr %14
}

declare dso_local i32 @_localtime64_s(ptr noundef, ptr noundef) local_unnamed_addr #1

declare dso_local i64 @_mkgmtime64(ptr noundef) local_unnamed_addr #1

define dso_local ptr @dlopen(ptr noundef %0, i32 noundef %1) local_unnamed_addr #0 {
  %3 = icmp eq ptr %0, null
  br i1 %3, label %4, label %6

4:                                                ; preds = %2
  %5 = tail call ptr @GetModuleHandleW(ptr noundef null) #10
  br label %24

6:                                                ; preds = %2
  %7 = tail call i32 @MultiByteToWideChar(i32 noundef 65001, i32 noundef 0, ptr noundef nonnull %0, i32 noundef -1, ptr noundef null, i32 noundef 0) #10
  %8 = icmp slt i32 %7, 1
  br i1 %8, label %14, label %9

9:                                                ; preds = %6
  %10 = shl nuw i32 %7, 1
  %11 = zext i32 %10 to i64
  %12 = tail call ptr @malloc(i64 noundef %11) #10
  %13 = icmp eq ptr %12, null
  br i1 %13, label %14, label %17

14:                                               ; preds = %9, %6
  %15 = phi i32 [ 22, %6 ], [ 12, %9 ]
  %16 = tail call ptr @_errno() #10
  store i32 %15, ptr %16, align 4
  store i32 87, ptr @dl_last_error, align 4
  br label %24

17:                                               ; preds = %9
  %18 = tail call i32 @MultiByteToWideChar(i32 noundef 65001, i32 noundef 0, ptr noundef nonnull %0, i32 noundef -1, ptr noundef nonnull %12, i32 noundef %7) #10
  %19 = tail call ptr @LoadLibraryW(ptr noundef nonnull %12) #10
  %20 = icmp eq ptr %19, null
  br i1 %20, label %21, label %23

21:                                               ; preds = %17
  %22 = tail call i32 @GetLastError() #10
  store i32 %22, ptr @dl_last_error, align 4
  br label %23

23:                                               ; preds = %21, %17
  tail call void @free(ptr noundef nonnull %12) #10
  br label %24

24:                                               ; preds = %14, %23, %4
  %25 = phi ptr [ %5, %4 ], [ %19, %23 ], [ null, %14 ]
  ret ptr %25
}

declare dso_local ptr @GetModuleHandleW(ptr noundef) local_unnamed_addr #1

declare dso_local ptr @LoadLibraryW(ptr noundef) local_unnamed_addr #1

define dso_local ptr @dlsym(ptr noundef %0, ptr noundef %1) local_unnamed_addr #0 {
  %3 = tail call ptr @GetProcAddress(ptr noundef %0, ptr noundef %1) #10
  %4 = icmp eq ptr %3, null
  br i1 %4, label %5, label %7

5:                                                ; preds = %2
  %6 = tail call i32 @GetLastError() #10
  store i32 %6, ptr @dl_last_error, align 4
  br label %7

7:                                                ; preds = %5, %2
  ret ptr %3
}

declare dso_local ptr @GetProcAddress(ptr noundef, ptr noundef) local_unnamed_addr #1

define dso_local range(i32 -1, 1) i32 @dlclose(ptr noundef %0) local_unnamed_addr #0 {
  %2 = tail call i32 @FreeLibrary(ptr noundef %0) #10
  %3 = icmp eq i32 %2, 0
  %4 = sext i1 %3 to i32
  ret i32 %4
}

declare dso_local i32 @FreeLibrary(ptr noundef) local_unnamed_addr #1

define dso_local noundef ptr @dlerror() local_unnamed_addr #0 {
  %1 = load i32, ptr @dl_last_error, align 4
  %2 = icmp eq i32 %1, 0
  br i1 %2, label %5, label %3

3:                                                ; preds = %0
  %4 = tail call i32 (ptr, i64, ptr, ...) @snprintf(ptr noundef nonnull @dlerror.text, i64 noundef 48, ptr noundef nonnull @"??_C@_0BB@OGGFDLON@Windows?5error?5?$CFu?$AA@", i32 noundef %1) #12
  store i32 0, ptr @dl_last_error, align 4
  br label %5

5:                                                ; preds = %0, %3
  %6 = phi ptr [ @dlerror.text, %3 ], [ null, %0 ]
  ret ptr %6
}

define dso_local range(i64 0, 2147483648) i64 @__jac_win_executable_path(ptr noundef %0, i64 noundef %1) local_unnamed_addr #0 {
  %3 = alloca [1024 x i16], align 16
  call void @llvm.lifetime.start.p0(i64 2048, ptr nonnull %3) #11
  %4 = call i32 @GetModuleFileNameW(ptr noundef null, ptr noundef nonnull %3, i32 noundef 1024) #10
  %5 = add i32 %4, -1024
  %6 = icmp ult i32 %5, -1023
  br i1 %6, label %21, label %7

7:                                                ; preds = %2
  %8 = trunc i64 %1 to i32
  %9 = add nsw i32 %8, -1
  %10 = call i32 @WideCharToMultiByte(i32 noundef 65001, i32 noundef 0, ptr noundef nonnull %3, i32 noundef %4, ptr noundef %0, i32 noundef %9, ptr noundef null, ptr noundef null) #10
  %11 = icmp slt i32 %10, 1
  br i1 %11, label %21, label %12

12:                                               ; preds = %7
  %13 = zext nneg i32 %10 to i64
  %14 = getelementptr inbounds nuw i8, ptr %0, i64 %13
  store i8 0, ptr %14, align 1
  br label %15

15:                                               ; preds = %19, %12
  %16 = phi ptr [ %0, %12 ], [ %20, %19 ]
  %17 = load i8, ptr %16, align 1
  switch i8 %17, label %19 [
    i8 0, label %21
    i8 92, label %18
  ]

18:                                               ; preds = %15
  store i8 47, ptr %16, align 1
  br label %19

19:                                               ; preds = %18, %15
  %20 = getelementptr inbounds nuw i8, ptr %16, i64 1
  br label %15

21:                                               ; preds = %15, %7, %2
  %22 = phi i64 [ 0, %2 ], [ 0, %7 ], [ %13, %15 ]
  call void @llvm.lifetime.end.p0(i64 2048, ptr nonnull %3) #11
  ret i64 %22
}

declare dso_local i32 @GetModuleFileNameW(ptr noundef, ptr noundef, i32 noundef) local_unnamed_addr #1

declare dso_local i32 @WideCharToMultiByte(i32 noundef, i32 noundef, ptr noundef, i32 noundef, ptr noundef, i32 noundef, ptr noundef, ptr noundef) local_unnamed_addr #1

define dso_local ptr @__jac_errno() local_unnamed_addr #0 {
  %1 = tail call ptr @_errno() #10
  ret ptr %1
}

define dso_local ptr @__jac_stdio(i32 noundef %0) local_unnamed_addr #6 {
  %2 = icmp eq i32 %0, 1
  %3 = icmp eq i32 %0, 0
  %4 = load ptr, ptr @stdin, align 8
  %5 = load ptr, ptr @stdout, align 8
  %6 = load ptr, ptr @stderr, align 8
  %7 = select i1 %2, ptr %5, ptr %6
  %8 = select i1 %3, ptr %4, ptr %7
  ret ptr %8
}

define dso_local noundef i32 @__jac_platform_id() local_unnamed_addr #4 {
  ret i32 2
}

define dso_local range(i32 -1, 1) i32 @__jac_stat(ptr noundef %0, ptr noundef writeonly captures(none) %1) local_unnamed_addr #0 {
  %3 = alloca %struct.linux_stat, align 8
  call void @llvm.lifetime.start.p0(i64 144, ptr nonnull %3) #11
  %4 = call i32 @stat(ptr noundef %0, ptr noundef nonnull %3) #12
  %5 = icmp eq i32 %4, 0
  br i1 %5, label %6, label %16

6:                                                ; preds = %2
  %7 = getelementptr inbounds nuw i8, ptr %3, i64 24
  %8 = load i32, ptr %7, align 8
  %9 = zext i32 %8 to i64
  store i64 %9, ptr %1, align 8
  %10 = getelementptr inbounds nuw i8, ptr %3, i64 48
  %11 = load i64, ptr %10, align 8
  %12 = getelementptr inbounds nuw i8, ptr %1, i64 8
  store i64 %11, ptr %12, align 8
  %13 = getelementptr inbounds nuw i8, ptr %3, i64 88
  %14 = getelementptr inbounds nuw i8, ptr %1, i64 16
  %15 = load <2 x i64>, ptr %13, align 8
  store <2 x i64> %15, ptr %14, align 8
  br label %16

16:                                               ; preds = %2, %6
  %17 = phi i32 [ 0, %6 ], [ -1, %2 ]
  call void @llvm.lifetime.end.p0(i64 144, ptr nonnull %3) #11
  ret i32 %17
}

define dso_local ptr @__jac_opendir(ptr noundef %0) local_unnamed_addr #0 {
  %2 = tail call ptr @opendir(ptr noundef %0) #12
  ret ptr %2
}

define dso_local ptr @__jac_readdir(ptr noundef %0) local_unnamed_addr #0 {
  %2 = tail call ptr @readdir(ptr noundef %0) #12
  ret ptr %2
}

define dso_local noundef i32 @__jac_closedir(ptr noundef %0) local_unnamed_addr #0 {
  %2 = load i64, ptr %0, align 8
  %3 = icmp eq i64 %2, -1
  br i1 %3, label %6, label %4

4:                                                ; preds = %1
  %5 = tail call i32 @_findclose(i64 noundef %2) #10
  br label %6

6:                                                ; preds = %1, %4
  tail call void @free(ptr noundef nonnull %0) #10
  ret i32 0
}

define dso_local nonnull ptr @__jac_dirent_name(ptr noundef readnone captures(ret: address, provenance) %0) local_unnamed_addr #4 {
  %2 = getelementptr inbounds nuw i8, ptr %0, i64 19
  ret ptr %2
}

define dso_local noundef i32 @__jac_at_fdcwd() local_unnamed_addr #4 {
  ret i32 -100
}

define dso_local range(i64 -1, 2147483648) i64 @__jac_executable_path(ptr noundef %0, i64 noundef %1) local_unnamed_addr #0 {
  %3 = alloca [1024 x i16], align 16
  call void @llvm.lifetime.start.p0(i64 2048, ptr nonnull %3) #11
  %4 = call i32 @GetModuleFileNameW(ptr noundef null, ptr noundef nonnull %3, i32 noundef 1024) #10
  %5 = add i32 %4, -1024
  %6 = icmp ult i32 %5, -1023
  br i1 %6, label %21, label %7

7:                                                ; preds = %2
  %8 = trunc i64 %1 to i32
  %9 = add nsw i32 %8, -1
  %10 = call i32 @WideCharToMultiByte(i32 noundef 65001, i32 noundef 0, ptr noundef nonnull %3, i32 noundef %4, ptr noundef %0, i32 noundef %9, ptr noundef null, ptr noundef null) #10
  %11 = icmp slt i32 %10, 1
  br i1 %11, label %21, label %12

12:                                               ; preds = %7
  %13 = zext nneg i32 %10 to i64
  %14 = getelementptr inbounds nuw i8, ptr %0, i64 %13
  store i8 0, ptr %14, align 1
  br label %15

15:                                               ; preds = %19, %12
  %16 = phi ptr [ %0, %12 ], [ %20, %19 ]
  %17 = load i8, ptr %16, align 1
  switch i8 %17, label %19 [
    i8 0, label %21
    i8 92, label %18
  ]

18:                                               ; preds = %15
  store i8 47, ptr %16, align 1
  br label %19

19:                                               ; preds = %18, %15
  %20 = getelementptr inbounds nuw i8, ptr %16, i64 1
  br label %15

21:                                               ; preds = %15, %7, %2
  %22 = phi i64 [ -1, %2 ], [ -1, %7 ], [ %13, %15 ]
  call void @llvm.lifetime.end.p0(i64 2048, ptr nonnull %3) #11
  ret i64 %22
}

define dso_local range(i64 -1, 49) i64 @__jac_addrinfo_layout(i32 noundef %0) local_unnamed_addr #4 {
  %2 = icmp ult i32 %0, 5
  br i1 %2, label %3, label %7

3:                                                ; preds = %1
  %4 = zext nneg i32 %0 to i64
  %5 = getelementptr inbounds nuw [5 x i64], ptr @switch.table.__jac_addrinfo_layout, i64 0, i64 %4
  %6 = load i64, ptr %5, align 8
  br label %7

7:                                                ; preds = %1, %3
  %8 = phi i64 [ %6, %3 ], [ -1, %1 ]
  ret i64 %8
}

define dso_local range(i32 0, 65536) i32 @__jac_sockaddr_family(ptr noundef readonly captures(none) %0) local_unnamed_addr #7 {
  %2 = load i16, ptr %0, align 1
  %3 = zext i16 %2 to i32
  ret i32 %3
}

define dso_local i64 @__jac_home_dir(ptr noundef %0, ptr noundef %1, i64 noundef %2) local_unnamed_addr #0 {
  %4 = alloca %struct.linux_passwd, align 8
  %5 = alloca ptr, align 8
  %6 = alloca [1024 x i8], align 16
  call void @llvm.lifetime.start.p0(i64 48, ptr nonnull %4) #11
  call void @llvm.lifetime.start.p0(i64 8, ptr nonnull %5) #11
  call void @llvm.lifetime.start.p0(i64 1024, ptr nonnull %6) #11
  %7 = load i8, ptr %0, align 1
  %8 = icmp eq i8 %7, 0
  br i1 %8, label %20, label %9

9:                                                ; preds = %3
  %10 = tail call ptr @getenv(ptr noundef nonnull @"??_C@_08JMMIJEMM@USERNAME?$AA@") #10
  store ptr null, ptr %5, align 8
  %11 = icmp eq ptr %10, null
  br i1 %11, label %23, label %12

12:                                               ; preds = %9
  %13 = tail call i64 @strlen(ptr noundef nonnull %10) #10
  %14 = tail call i64 @strlen(ptr noundef nonnull %0) #10
  %15 = icmp eq i64 %13, %14
  br i1 %15, label %16, label %23

16:                                               ; preds = %12
  %17 = tail call i64 @strlen(ptr noundef nonnull %0) #10
  %18 = tail call i32 @memcmp(ptr noundef nonnull %10, ptr noundef nonnull %0, i64 noundef %17) #10
  %19 = icmp eq i32 %18, 0
  br i1 %19, label %20, label %23

20:                                               ; preds = %3, %16
  %21 = call fastcc i32 @current_user(ptr noundef nonnull %4, ptr noundef nonnull %6, i64 noundef 1024, ptr noundef nonnull %5) #12
  %22 = icmp ne i32 %21, 0
  br label %23

23:                                               ; preds = %20, %16, %12, %9
  %24 = phi i1 [ false, %16 ], [ false, %12 ], [ false, %9 ], [ %22, %20 ]
  %25 = load ptr, ptr %5, align 8
  %26 = icmp eq ptr %25, null
  %27 = select i1 %24, i1 true, i1 %26
  br i1 %27, label %39, label %28

28:                                               ; preds = %23
  %29 = getelementptr inbounds nuw i8, ptr %4, i64 32
  %30 = load ptr, ptr %29, align 8
  %31 = icmp eq ptr %30, null
  br i1 %31, label %39, label %32

32:                                               ; preds = %28
  %33 = call i64 @strlen(ptr noundef nonnull %30) #10
  %34 = icmp slt i64 %33, %2
  br i1 %34, label %35, label %39

35:                                               ; preds = %32
  %36 = add nsw i64 %33, 1
  %37 = load ptr, ptr %29, align 8
  %38 = call ptr @memcpy(ptr noundef %1, ptr noundef %37, i64 noundef %36) #10
  br label %39

39:                                               ; preds = %32, %35, %28, %23
  %40 = phi i64 [ -1, %23 ], [ -2, %28 ], [ %33, %35 ], [ %33, %32 ]
  call void @llvm.lifetime.end.p0(i64 1024, ptr nonnull %6) #11
  call void @llvm.lifetime.end.p0(i64 8, ptr nonnull %5) #11
  call void @llvm.lifetime.end.p0(i64 48, ptr nonnull %4) #11
  ret i64 %40
}

define dso_local range(i64 -1, 5) i64 @__jac_clock_id(i32 noundef %0) local_unnamed_addr #4 {
  %2 = icmp ult i32 %0, 6
  br i1 %2, label %3, label %7

3:                                                ; preds = %1
  %4 = zext nneg i32 %0 to i64
  %5 = getelementptr inbounds nuw [6 x i64], ptr @switch.table.__jac_clock_id, i64 0, i64 %4
  %6 = load i64, ptr %5, align 8
  br label %7

7:                                                ; preds = %1, %3
  %8 = phi i64 [ %6, %3 ], [ -1, %1 ]
  ret i64 %8
}

define dso_local noundef i32 @__jac_sleep_ns(i64 noundef %0) local_unnamed_addr #0 {
  tail call fastcc void @sleep_ns(i64 noundef %0) #12
  ret i32 0
}

define dso_local i64 @__jac_malloc_size(ptr noundef %0) local_unnamed_addr #0 {
  %2 = tail call i64 @_msize(ptr noundef %0) #10
  ret i64 %2
}

declare dso_local i64 @_msize(ptr noundef) local_unnamed_addr #1

define dso_local noundef double @__jac_fmadd(double noundef %0, double noundef %1, double noundef %2) local_unnamed_addr #4 {
  %4 = fmul double %0, %1
  %5 = fadd double %4, %2
  ret double %5
}

define dso_local ptr @__jac_va_list(ptr noundef readonly captures(none) %0) local_unnamed_addr #7 {
  %2 = load ptr, ptr %0, align 8
  ret ptr %2
}

define dso_local i64 @__jac_va_i64(ptr noundef captures(none) %0) local_unnamed_addr #8 {
  %2 = load ptr, ptr %0, align 8
  %3 = getelementptr inbounds nuw i8, ptr %2, i64 8
  store ptr %3, ptr %0, align 8
  %4 = load i64, ptr %2, align 8
  ret i64 %4
}

define dso_local double @__jac_va_f64(ptr noundef captures(none) %0) local_unnamed_addr #8 {
  %2 = load ptr, ptr %0, align 8
  %3 = getelementptr inbounds nuw i8, ptr %2, i64 8
  store ptr %3, ptr %0, align 8
  %4 = load double, ptr %2, align 8
  ret double %4
}

define dso_local void @__jac_win_floor_init() local_unnamed_addr #0 {
  %1 = tail call ptr @__acrt_iob_func(i32 noundef 0) #10
  store ptr %1, ptr @stdin, align 8
  %2 = tail call ptr @__acrt_iob_func(i32 noundef 1) #10
  store ptr %2, ptr @stdout, align 8
  %3 = tail call ptr @__acrt_iob_func(i32 noundef 2) #10
  store ptr %3, ptr @stderr, align 8
  %4 = tail call ptr @setlocale(i32 noundef 2, ptr noundef nonnull @"??_C@_06PFLEPMKG@?4UTF?98?$AA@") #10
  %5 = tail call i32 @SetConsoleOutputCP(i32 noundef 65001) #10
  %6 = tail call i32 @SetConsoleCP(i32 noundef 65001) #10
  ret void
}

declare dso_local ptr @__acrt_iob_func(i32 noundef) local_unnamed_addr #1

declare dso_local ptr @setlocale(i32 noundef, ptr noundef) local_unnamed_addr #1

declare dso_local i32 @SetConsoleOutputCP(i32 noundef) local_unnamed_addr #1

declare dso_local i32 @SetConsoleCP(i32 noundef) local_unnamed_addr #1

declare dso_local ptr @memset(ptr noundef, i32 noundef, i64 noundef) local_unnamed_addr #1

declare dso_local i32 @MultiByteToWideChar(i32 noundef, i32 noundef, ptr noundef, i32 noundef, ptr noundef, i32 noundef) local_unnamed_addr #1

declare dso_local ptr @CreateWaitableTimerExW(ptr noundef, ptr noundef, i32 noundef, i32 noundef) local_unnamed_addr #1

declare dso_local i32 @SetWaitableTimer(ptr noundef, ptr noundef, i32 noundef, ptr noundef, ptr noundef, i32 noundef) local_unnamed_addr #1

declare dso_local void @Sleep(i32 noundef) local_unnamed_addr #1

declare i32 @llvm.smax.i32(i32, i32) #9

declare i64 @llvm.umin.i64(i64, i64) #9

attributes #0 = { nounwind uwtable "no-builtins" }
attributes #1 = { "no-builtins" }
attributes #2 = { mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #3 = { mustprogress nocallback nofree nosync nounwind willreturn }
attributes #4 = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable "no-builtins" }
attributes #5 = { mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: write) uwtable "no-builtins" }
attributes #6 = { mustprogress nofree norecurse nosync nounwind willreturn memory(read, argmem: none, inaccessiblemem: none) uwtable "no-builtins" }
attributes #7 = { mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: read) uwtable "no-builtins" }
attributes #8 = { mustprogress nofree norecurse nosync nounwind willreturn memory(read, argmem: readwrite, inaccessiblemem: none) uwtable "no-builtins" }
attributes #9 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #10 = { nobuiltin nounwind "no-builtins" }
attributes #11 = { nounwind }
attributes #12 = { nobuiltin "no-builtins" }
""";
