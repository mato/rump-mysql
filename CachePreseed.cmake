#
# CMake cache pre-seeds for MySQL build.
#

# Provide result of TRY_RUN() test.
SET( HAVE_LLVM_LIBCPP_EXITCODE 
     "1"
     CACHE STRING "Result from TRY_RUN" FORCE)

# Need to force this as it is provided by libc headers but not present as a
# plain symbol in libc. If not set MySQL helpfully provides its own
# implementation which conflicts with ours.
SET( HAVE_SIGWAIT
     "1"
     CACHE STRING "Have sigwait()" FORCE)

# Don't try to use times(2) in my_timer routines.
SET( HAVE_TIMES
     "0"
     CACHE STRING "Have times()" FORCE)
