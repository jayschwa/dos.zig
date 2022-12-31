# Resize the program's memory block and update its code and data segment base
# addresses. This function must be entered with a far call.
#
# Inputs:
# AX    = alternate data segment
# BX:CX = new size of block
# SI:DI = memory block handle
#
# Outputs:
# AX    = error code
# BX:CX = new base address
# SI:DI = new memory block handle

.global resize_self;
resize_self:

# Save the caller's registers to the caller's stack.
pushw %dx
pushw %es
pushw %fs
pushw %gs

# Save the caller's primary segment registers to the extra segment registers.
mov 12(%esp), %es # Caller's CS is on the stack before previous pushes and EIP.
push %ds
pop %fs
push %ss
pop %gs

# Switch to the alternate data segment.
mov %ax, %ds
mov %ax, %ss

# Resize memory block. Inputs are set by caller.
mov $0x503, %ax
int $0x31
jc .L_finish_2

# Shift new linear address from BX:CX to CX:DX.
mov %cx, %dx
mov %bx, %cx

# Update base address of caller's code and data segments.
mov $0x7, %ax
mov %es, %bx
int $0x31
mov %fs, %bx
int $0x31
jc .L_finish_1

# Clear error code register.
xor %ax, %ax

.L_finish_1:

# Move linear address back to BX:CX for caller.
mov %cx, %bx
mov %dx, %cx

.L_finish_2:

# Restore caller's primary segment registers.
push %fs
pop %ds
push %gs
pop %ss

# Restore caller's extra segment registers.
popw %gs
popw %fs
popw %es
popw %dx

lret

.global resize_self_end;
resize_self_end:
