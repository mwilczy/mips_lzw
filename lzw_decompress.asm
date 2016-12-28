	.data
.align 2
out: .space 1048576
#data: .asciiz "TOBEORNOTTOBEORTOBEORNOT"
prompt_input: .asciiz "Input file\n"
prompt_output: .asciiz "Output file\n"
data: .space 1048576 # 1 Megabyte of memory
file_path: .space 255
file_path_out: .space 255
.align 4
dict: .space 16384 # pointers
.align 4
dict_entries_size: .space 4096
buffer: .space 100
	.text
main:
	# initialize dictionary with basic ASCII set
	# $t0 - pointer(dictionary)
	# $t1 - dict_entries_size
	# $t2 - 0 (loop_counter)
	# $t3 - const = 255
	# $s7 - 1 (const)
	# $s0 - dict_size
	# $s6 = leftover boolean
	# $s5 = leftover bits
	# $s4 = buffer size
	# $s3 = buffer (pointer)
	# $s2 = data (pointer)
	# $s1 = check_if_exists_loop_counter
	# $t8 = check_if_exists_inner_loop_counter
	# $a3 = global_out_counter
	
	li $v0,4
	la $a0,prompt_input
	syscall
	# read file path from stdin
	li $v0,8
	la $a0,file_path
	li $a1,255
	syscall
	# remove newline from the end of file
	la $a0,file_path
remove_newline:
	lb $v0,($a0)
	addiu $a0,$a0,1
	bne $v0,'\n',remove_newline
	sb $zero,-1($a0)
	
	li $v0,4
	la $a0,prompt_output
	syscall
	
	li $v0,8
	la $a0,file_path_out
	li $a1,255
	syscall
	# remove newline from the end of file
	la $a0,file_path
remove_newline2:
	lb $v0,($a0)
	addiu $a0,$a0,1
	bne $v0,'\n',remove_newline2
	sb $zero,-1($a0)
	
	
###########################
	li $v0,13
	la $a0,file_path
	li $a1,0 # read only
	syscall
	move $a0,$v0
	li $v0,14
	la $a1,data
	li $a2,1048576
	syscall
	move $v1,$v0
	#li $v1,23 # length of our input size - 1
	la $t0,dict
	la $t1,dict_entries_size
	li $t2, 0
	li $s7,1
	li $s1, 0
	
	li $a3,0
# same dictionary as in compression
create_dict_loop:
	# writing size to dict_entries_size
	sb $s7,($t1)
	# allocating memory for dict entry
	li $v0, 9
	li $a0, 1
	syscall
	# writing basic ASCII dict
	sw $v0,($t0)
	sb $t2,($v0)
	
	
	addiu $t0,$t0,4 #increment dict_pointer
	addiu $t1,$t1,1 #increment dict_entries_size array
	addiu $t2,$t2,1 #increment loop counter
	addiu $s0,$s0,1 #increment dict_size
	ble $t2,255,create_dict_loop
	#subiu $s0,$s0,1
	
	li $s6,0 # leftover
	li $s4,1 # buffer size
	la $s3, buffer # buffer pointer
	la $s2, data # data pointer
	lb $t9,($s2) 
	sb $t9,($s3)
	addiu $s3,$s3,1
	li $t2,0
	
	la $s7,out # output buffer
	li $s6,0
	li $s5,0
	la $s2,data
	li $s4,0 # conjecture size
	# leftover boolean = $s6
	# leftover bits = $s5
	# compressed data  = $s2
	# $t5 = code, it's also output code (12 bits)
	# $t6 = next_code
	
	li $t7,0 # counter of output
	
decompress_loop:
	
read_12_bits_from_file:
	lbu $t5,($s2)
	addiu $s2,$s2,1
	beq $s6,$zero,no_leftover
leftover_exists:
	sll $s5,$s5,8
	addu $t5,$t5,$s5
	li $s6,0 # set lefover boolean
	addiu $t2,$t2,1
	b end_reading_data
no_leftover:
	#li $s5,0
	lbu $t6,($s2)
	addiu $s2,$s2,1
	addiu $t2,$t2,2
	li $a3,0xF
	and $s5,$t6,$a3 # setting leftover bits
	li $s6,1 # set leftover boolean
	sll $t5,$t5,4
	srl $t6,$t6,4
	addu $t5,$t5,$t6
	# done out in $t5 (12 bits)
	# it's index in a dictionary
end_reading_data:
	# check if index exists in dictionary
	# String+Char+String+Char+String exception
	blt $t5,$s0,no_exception
	# here exception occured
	# now we take an old buffer and add the first letter to the end
exception_occured:
	la $s3,buffer
	lb $t8,($s3)
	addu $s3,$s3,$s4
	sb $t8,($s3)
	addiu $s4,$s4,1
	la $s3,buffer

	#adding to dictionary
	la $t1,dict_entries_size
	addu $t1,$t1,$s0
	#addiu $s4,$s4,1
	sb $s4,($t1)
	#subiu $s4,$s4,1
	subu $t1,$t1,$s0
	# now add to dict
	# first allocate memory for 
	li $v0,9
	move $a0,$s4
	syscall
	# now assign new address to dictionary
	la $t0,dict
	# we need to multiply $s2 * 4
	# we use logical shift left
	sll $s0,$s0,2
	addu $t0,$t0,$s0
	sw $v0,($t0)
	srl $s0,$s0,2
	addiu $s0,$s0,1
	# now copy all bytes from buffer to dict_buffer
	# $a0 = loop_counter
	li $a0,0
	la $s3,buffer
memcpy_loop_add_to_dict2:
	lb $a1,($s3)
	sb $a1,($v0)
	addiu $a0,$a0,1
	addiu $s3,$s3,1
	addiu $v0,$v0,1
	blt $a0,$s4,memcpy_loop_add_to_dict2

	b end_decompress_loop
no_exception:
	beq $s4,$zero,carry_on
add_dict_entry_if_possible:
	# take conjecture buffer and add first character from dictionary to it,
	# then add new dictionary entry as-is
	# we're reconstructing dictionary
	# buffer is a conjecture
	la $s3,buffer
	#subiu $s4,$s4,1
	addu $s3,$s3,$s4
	#sb $t5,($s3) # wtf ?
	# load string from dictionary
	la $t0,dict
	sll $t5,$t5,2
	addu $t0,$t0,$t5
	lw $a2,($t0)
	lb $a2,($a2)
	sb $a2,($s3)
	srl $t5,$t5,2
	addiu $s4,$s4,1 # it technically contains one character more
	
	la $t1,dict_entries_size
	addu $t1,$t1,$s0
	#addiu $s4,$s4,1
	sb $s4,($t1)
	#subiu $s4,$s4,1
	subu $t1,$t1,$s0
	# now add to dict
	# first allocate memory for 
	li $v0,9
	move $a0,$s4
	syscall
	# now assign new address to dictionary
	la $t0,dict
	# we need to multiply $s2 * 4
	# we use logical shift left
	sll $s0,$s0,2
	addu $t0,$t0,$s0
	sw $v0,($t0)
	srl $s0,$s0,2
	addiu $s0,$s0,1
	# now copy all bytes from buffer to dict_buffer
	# $a0 = loop_counter
	li $a0,0
	la $s3,buffer
memcpy_loop_add_to_dict:
	lb $a1,($s3)
	sb $a1,($v0)
	addiu $a0,$a0,1
	addiu $s3,$s3,1
	addiu $v0,$v0,1
	blt $a0,$s4,memcpy_loop_add_to_dict

	subiu $s4,$s4,1
	
	# look up for dictionary index
carry_on:
	la $t0,dict
	la $t1,dict_entries_size
	la $s3,buffer
	addu $t1,$t1,$t5 # get the size of dictionary sequence
	sll $t5,$t5,2 # multiply index by 4, since dictionary contains pointers
	addu $t0,$t0,$t5
	# we need to copy bytes from dictionary index to temporary buffer serving as conjecture
	lb $t9,($t1) # size of dictionary buffer
	li $t8,0
	#move $s4,$t9 # size of dictionary
	move $s4,$t9
	lw $s7,($t0)
memcpy_conjecture:
	lb $t3,($s7)
	sb $t3,($s3)
	addiu $s7,$s7,1
	addiu $s3,$s3,1
	addiu $t8,$t8,1
	blt $t8,$t9,memcpy_conjecture
end_decompress_loop:
	#addiu $t2,$t2,1
	# write output = conjecture
	# $t6 = loop counter
	# $t7 = output counter
	li $t6,0
	la $t8,out
	addu $t8,$t8,$t7
	la $s3,buffer
write_output:
	lb $s1,($s3)
	sb $s1,($t8)
	addiu $s3,$s3,1
	addiu $t8,$t8,1
	addiu $t6,$t6,1
	addiu $t7,$t7,1
	blt $t6,$s4,write_output
	
	blt $t2,$v1,decompress_loop
	
	# now write output to the file
	li $v0,13
	la $a0,file_path_out
	li $a1,1
	syscall
	move $a0,$v0
	li $v0,15
	la $a1,out	
	move $a2,$t7
	syscall

exit:
	li $v0,10
	syscall
	
	
