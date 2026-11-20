x, y, z = 9, 2, 3
a, b, c, d, e, f, g = 10, 3, 2, 5, 7, 4, 6
w = 80
title_len = 11

t1 = (a - b - c) // 2
t2 = ((a - b - c) // 2) + d
t3 = (a + b + c) * d
t4 = (a - b - c) * (d + e + f)
t5 = (a + b + c) * (d - e - f) // g

pad1 = (w - title_len - 2) // 2
pad2 = (w - title_len - 1) // 2

m1 = (a - b - c) % d
m2 = (a + b + c) % d
m3 = ((a - b - c) % d) // 2
m4 = ((a + b + c) % d) // 2

u1 = ((a - b - c) // 2) * ((d + e + f) - (g + x + y))
u2 = -((a + b + c) // (x + y)) + ((d - e - f) * (z + 1))
u3 = ((a - b - c) // (x + y + z)) - ((d - e - f) // (x - y - z))

p1 = ((a - b - c) // 2) > (d + e)
p2 = ((a + b + c) * 3) <= ((d - e - f) // 2)
p3 = (((a - b - c) // 2) > 0) and (((d - e - f) // 2) < 10)
p4 = (((a + b + c) % 5) == 0) or (((d + e + f) // 3) != 2)

print(t1, t2, t3, t4, t5)
print(m1, m2, m3, m4)
print(u1, u2, u3)
print(p1, p2, p3, p4)
