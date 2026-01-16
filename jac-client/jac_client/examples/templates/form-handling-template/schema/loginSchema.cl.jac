import from zod { z}

# Login Schema
glob schema = z.object({
    "username": z
            .string()
            .min(1, "Username is required"),
    "password": z.string().min(6, "Password must be at least 6 characters long"),

});


def:pub loginSchema()-> any{
    return schema;
}
