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
dict_entries_size: .space 1024
buffer: .space 100
	.text
# assume
# $t0 = dictionary
# $t1 = dict_entries_size
# $t2 = loop_counter
# $s0 = data
# $s1 = dict_size
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

#################################
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
compress_loop:
	addiu $s2,$s2,1
	lb $t9,($s2)
	sb $t9,($s3) # store data in the buffer
	
	# check if created sequence exists in dictionary
	# $s1 = loop counter
	# $s0 = dict size
	
	li $s1,0 # loop counter
	la $t1, dict_entries_size
	la $t0,dict
	addiu $s4,$s4,1
	
	beq $s4,1,check_if_exists_for
	addiu $t1,$t1,255
	li $s1,255
	addiu $t0,$t0,1020
check_if_exists_for:
	#addu $t1,$t1,$s1
	lb $t9,($t1) #
	#subu $t1,$t1,$s1
	bne $s4,$t9,end_check_if_exists_loop
	# load desired buffer
	li $t8,0
	lw $t7,($t0)
	la $t5, buffer
check_if_exists_inner_for_loop:
	lb $t6,($t7)
	lb $t4,($t5)
	bne $t6,$t4,end_check_if_exist_inner_for_loop
	addiu $t8,$t8,1
	addiu $t7,$t7,1
	addiu $t5,$t5,1
	bne $t8,$t9,check_if_exists_inner_for_loop
end_check_if_exist_inner_for_loop:
	# return in case we find string in dictionary
	# index is saved in $s2
	beq $t8,$t9,exists_in_dict_just_add_more_characters
	# we know that it does not equal, but it may equal without last character
	#subiu $t9,$t9,1
	#bne $t8,$t9,end_check_if_exists_loop
	#move $a3,$s1
end_check_if_exists_loop:
	addiu $t1,$t1,1
	addiu $s1,$s1,1	
	addiu $t0,$t0,4 # we're iterating through whole dictionary
	ble $s1,$s0 check_if_exists_for

doesnt_exist_add_to_dict_write_output:
	subiu $s4,$s4,1
	# write size of new elem in dict_entries_size
	la $t1,dict_entries_size
	addu $t1,$t1,$s0
	addiu $s4,$s4,1
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
	# we also need to save the output
	# do the dictionary lookup for our code
	
	li $s1,0 # loop counter
	la $t1, dict_entries_size
	la $t0,dict
	subiu $s4,$s4,1
#################################
	beq $s4,1,check_if_exists_for2
	addiu $t1,$t1,255
	li $s1,255
	addiu $t0,$t0,1020
check_if_exists_for2:
	#addu $t1,$t1,$s1
	lb $t9,($t1) #
	#subu $t1,$t1,$s1
	bne $s4,$t9,end_check_if_exists_loop2
	# load desired buffer
	li $t8,0
	lw $t7,($t0)
	la $t5, buffer
check_if_exists_inner_for_loop2:
	lb $t6,($t7)
	lb $t4,($t5)
	bne $t6,$t4,end_check_if_exist_inner_for_loop2
	addiu $t8,$t8,1
	addiu $t7,$t7,1
	addiu $t5,$t5,1
	bne $t8,$t9,check_if_exists_inner_for_loop2
end_check_if_exist_inner_for_loop2:
	# return in case we find string in dictionary
	# index is saved in $s2
	beq $t8,$t9,write_output
	# we know that it does not equal, but it may equal without last character
	#subiu $t9,$t9,1
	#bne $t8,$t9,end_check_if_exists_loop
	#move $a3,$s1
end_check_if_exists_loop2:
	addiu $t1,$t1,1
	addiu $s1,$s1,1
	addiu $t0,$t0,4 # we're iterating through whole dictionary
	ble $s1,$s0 check_if_exists_for2
	#sb $a3,($s7)
	#addiu $s7,$s7,1
#################################
# out = $s1
# leftover boolean = $s6
# leftover bits = $s5
write_output:
	beq $s6,1,leftover_exists
no_leftover:
	li $t4,0xF
	and $s5,$s1,$t4
	li $s6,1
	sra $s1,$s1,4
	sb $s1,($s7)
	addiu $s7,$s7,1
	addiu $a3,$a3,1
	b write_out_12_bits
leftover_exists:
	sll $s5,$s5,4
	sra $t4,$s1,8
	addu $t6,$s5,$t4 # previous code
	sb $t6,($s7)
	addiu $s7,$s7,1
	sb $s1,($s7)
	addiu $s7,$s7,1
	li $s6,0
	li $s5,0
	addiu $a3,$a3,2
write_out_12_bits:
	#sh $s1,($s7)
	#addiu $s7,$s7,2
	#subiu $s1,$s1,1
	# buffer_size = 1
	li $s4,1
	la $s3,buffer
	# buffer[0] = text[i+1]
	lb $a0,($s2)
	sb $a0,($s3)
	addiu $s3,$s3,1
	
	b end_compress_loop
	
	
	
exists_in_dict_just_add_more_characters:
	subiu $s4,$s4,1				
	addiu $s4,$s4,1
	addiu $s3,$s3,1
end_compress_loop:
	addiu $t2,$t2,1
	blt $t2,$v1, compress_loop
	
	# write leftover bits
	beq $s5,$zero,write_compressed_file
	sll $s5,$s5,4
	sb $s5,($s7)
	addiu $s7,$s7,1
	addiu $a3,$a3,1
write_compressed_file:
	li $v0,13
	la $a0,file_path_out
	li $a1,1
	syscall
	move $a0,$v0
	li $v0,15
	la $a1,out	
	move $a2,$a3
	syscall

exit:
	li $v0,10
	syscall
	
#check_if_exists_compare_for:
	
	
	
	
	
	
	
	
	
	
	
	
