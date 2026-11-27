namespace ParcelHub.Api.Auth;

// บทบาทผู้ใช้ — ตรงกับ CHECK ของคอลัมน์ AppUser.Role
public static class Roles
{
    public const string Staff = "Staff";
    public const string DataSteward = "DataSteward";
    public const string Admin = "Admin";
}

// สิทธิ์ขั้นต่ำของ endpoint (ลำดับขั้น: Admin ⊃ DataSteward ⊃ Staff)
public static class Policies
{
    public const string StaffUp = "StaffUp";
    public const string StewardUp = "StewardUp";
    public const string AdminOnly = "AdminOnly";
}
