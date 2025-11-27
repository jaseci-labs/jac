cl import from zod { z}

cl {
    # Registration Schema
    let _registrationSchema = z
    .object({
        "username": z.string()
      .min(3, "Username must be at least 3 characters")
      .max(20, "Username must be less than 20 characters"),

        "email": z.string().email("Invalid email address"),
        "password": z.string().min(6, "Password must be at least 6 characters long"),
        "confirmPassword": z.string().min(6, "Password must be at least 6 characters long"),
        "age": z.number().min(18, "You must be at least 18 years old"),
        "agreeToTerms": z.boolean({
        "required_error": "You must agree to the terms and conditions",
        "invalid_type_error": "You must agree to the terms and conditions",
      }).refine(lambda val: bool -> bool {
            console.log("Agree to terms value:", val);
            return val == true;
        }, {
            "message": "You must agree to the terms and conditions"
        })

    }).refine(lambda data: dict -> bool {
            return data.password == data.confirmPassword;
        }, {
            "message": "Passwords do not match",
            "path": ["confirmPassword"]
        });

    # Login Schema
    let _loginSchema = z.object({
        "email": z
                .string()
                .min(1, "Email is required")
                .email("Please enter a valid email address"),
        "password": z.string().min(6, "Password must be at least 6 characters long"),
        "rememberMe": z.boolean().optional()
    });

    # Profile Schema
    let _profileSchema = z.object({
        "displayName": z.string().min(1, "Display name is required"),
        "bio": z.string().max(300, "Bio cannot exceed 300 characters"),
        "website": z.string().url("Invalid URL").optional(),
        "notifications": z.object({
            "email": z.boolean(),
            "sms": z.boolean(),
            "push": z.boolean()
        })
    });

    # Contact Schema
    let _contactSchema = z.object({
        "name": z.string().min(1, "Name is required"),
        "email": z.string().email("Invalid email address"),
        "subject": z.string()
    .min(5, "Subject must be at least 5 characters")
    .max(100, "Subject must be less than 100 characters"),
        "message": z.string()
    .min(5, "Subject must be at least 5 characters")
    .max(100, "Subject must be less than 100 characters"),
        "category": z.enum(["general", "support", "feedback", "bug"], {
            "message": "Category is required"
        })
    });

    def registrationSchema()-> any{
        return _registrationSchema;
    }

    def loginSchema()-> any{
        return _loginSchema;
    }
    def profileSchema()-> any{
        return _profileSchema;
    }
    def contactSchema()-> any{
        return _contactSchema;
    }
}
