import random;
import string;

"""Generate a random password with specified length.

Args:
    length: The length of the password to generate (default: 8)

Returns:
    A random password string containing letters, digits, and special characters
"""
def generate_random_password(length: int = 8) -> str {
    characters = string.ascii_letters + string.digits + string.punctuation;
    password_chars = [random.choice(characters) for _ in range(length)];
    return ''.join(password_chars);
}
