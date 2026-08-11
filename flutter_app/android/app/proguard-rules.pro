# Room loads generated database implementations reflectively. AGP 9/R8 full
# mode no longer keeps a default constructor merely because it keeps a class
# name, which otherwise crashes WorkManager before Flutter starts.
-keep class * extends androidx.room.RoomDatabase {
    public <init>();
}
