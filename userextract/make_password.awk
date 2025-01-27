#!/usr/bin/awk -f
# make_password.awk - Make random password(s).

# Usage: awk -f make_password.awk [-v num=n] [-v len=n] [-v debug=1]
#  Generates one password by default.
#	Use -v num=n on the command line to specify the number of passwords.
#   (num must be >= 1; the default is 1)
#  Generates eight-character passwords by default.
#	Use -v len=n on the command line to specify the length of the passwords. 
#   (len must be >= 8 and <= 16; the default is 8)

# A function is provided here that gets a random character from a source 
# string that is not already in a destination string.  It is used in both 
# steps of the password generation.  
#
# The first step is to randomly choose the unique characters that will be 
# in the password.  It does it by choosing characters at random from 
# candidate lowercase, uppercase, numeric, and special characters that have
# not already been chosen. 
#
# The second step is to scramble the characters that were chosen.  It does
# that by choosing characters at random from the already-chosen password 
# characters until all of them have been chosen. 
#
# The result of the two steps is a scrambled string containing random, unique
# password characters.

# CAUTION:
# Nothing has been done to automatically reject generated passwords that
# contain "offensive words".  Visually inspect the generated passwords.

BEGIN {
	identification = "make_password"
	
    # Was -v debug=n was specified, with n > 0?
    if(debug != 0) {
        debug = 1
    }

    # Seed the random number generator.  
    # Gnu AWK uses system time by default, like most do.  
    # This is not specified by POSIX, though, so
    # check your implementation to make sure the sequence 
    # of "random" numbers is not repeated from one run to 
    # the next.
    # 
    # Using srand() with the default system time seed allowed me to
    # run a few executions fast enough that the system time didn't 
    # change.  This resulted in repeated groups of passwords.
    #
    # Calculating the seed using the system time and the last PID fixed it.
    # Every run generates different passwords.
    random_seed = calculate_seed()
    if(debug) {
        printf("%s: random number seed: %ld\n", identification, random_seed)
    }
	srand(random_seed)

	# Determine the number of passwords to print.
    min_pswd_num = 1
	pswd_num = default_pswd_num = min_pswd_num
	if(num != "") {
		# "-v num=n" was specified on the command line.
		pswd_num = int(num)
		if(pswd_num < min_pswd_num) {
			pswd_num = default_pswd_num
			printf("%s: Number of passwords specified (%s) was less than the minimum number %d; it was set to the default %d\n", 
                    identification, num, min_pswd_num, pswd_num)
		}
	}

	# Determine the length of the passwords to print.
	min_pswd_len = 8
    max_pswd_len = 16
	pswd_len = default_pswd_len = min_pswd_len
	if(len != "") {
		# "-v len=n" was specified on the command line.
		pswd_len = int(len)
		if(pswd_len < min_pswd_len) {
			pswd_len = default_pswd_len
			printf("%s: Password length specified (%s) was less than the minimum length %d; it was set to the default %d\n", 
                    identification, len, min_pswd_len, pswd_len)
		}
		if (pswd_len > max_pswd_len) {
			pswd_len = default_pswd_len
			printf("%s: Password length specified (%s) was greater than the maximum length %d; it was set to the default %d\n", 
                    identification, len, max_pswd_len, pswd_len)
		}
	}

	if (debug) {
		printf("%s: pswd_num: %d, pswd_len: %d\n", identification, pswd_num, pswd_len)
    }

	# Print the password(s).
	# for(pswd_loop = 0; pswd_loop < pswd_num; pswd_loop++) {
    #     pswd = generate_password(pswd_len) 
    #     if(debug) {
    #         printf("pswd: ")
    #     }
	# 	printf("%s", pswd)
    #     if(debug) {
    #         printf(" (length=%d)", length(pswd))
    #     }
    #     printf("\n")
	# }
}

# Generate one password.
function generate_password(pswd_len) {	
	characters = get_password_characters(pswd_len)
	password   = scramble(characters)
	return password
}

# Get the password characters from the various candidate character strings.
function get_password_characters(pswd_len) {
	# Initialize the candidate password character strings.
	# (I don't include the I, l, O, o, 1, or 0 characters in the passwords
	#  because they might be misread, depending on the user's font.)
	lowercase_candidates="abcdefghijkmnpqrstuvwxyz"
	uppercase_candidates="ABCDEFGHJKLMNPQRSTUVWXYZ"
	numeric_candidates="23456789"
	#special_candidates="!@#$%^&*-_=+/"
	special_candidates="!#%^*-_=+/"

	# Here is where you can set the number of the various candidate characters.
	lowercase_num = 3
	uppercase_num = 2
	numeric_num = 2
	special_num = 1

	# Here is where you can set how the numbers of the various candidate
	# characters increase depending on the password length.
	if (pswd_len > 8) {
		uppercase_num++
	}
	if (pswd_len > 9) {
		numeric_num++
	}
	if (pswd_len > 10) {
		special_num++
	}
	if (pswd_len > 11) {
		lowercase_num++
	}
	if (pswd_len > 12) {
		uppercase_num++
	}
	if (pswd_len > 13) {
		numeric_num++
	}
	if (pswd_len > 14) {
		special_num++
	}
	if (pswd_len > 15) {
		lowercase_num++
	}

	if (debug) {
		printf("%s: lowercase_num:%d,uppercase_num:%d,numeric_num:%d,special_num:%d, \t",
			    identification, lowercase_num, uppercase_num, numeric_num, special_num)
	}

	# Select and concatenate the password characters.
	p = ""
	p = p get_random_unique_characters(p, lowercase_candidates, lowercase_num)
	p = p get_random_unique_characters(p, uppercase_candidates, uppercase_num)
	p = p get_random_unique_characters(p, numeric_candidates, numeric_num)
	p = p get_random_unique_characters(p, special_candidates, special_num)
	
	if (debug) {
		printf("pswd characters: %s (length=%d) \t", p, length(p))
	}
	
	return p
}

# Get a random number between 1 and n, inclusive.
function get_random_int(n) {
	r = 1 + int(rand() * n)
	return r
}

# Get up to the specified number of random characters from possibles that are not already in str.
# Return the characters, or "" if all the possibles are already in str.
# May return less than the specified number of characters if it runs out of
# possibles before the specified number is reached. 
function get_random_unique_characters(str, possibles, char_num) {
	chars = ""
	str_chars = str chars
	for (char_loop = 0; char_loop < char_num; char_loop++) {
		ch = get_random_unique_character(str_chars, possibles)
		if (ch != "") {
			chars = chars ch
			str_chars = str chars
		}
		else {
			break
		}
	}
	return chars
}

# Get a random character from possibles that is not already in str.
# Return "" if all the possibles are already in str.
function get_random_unique_character(str, possibles) {
	possibles_len = length(possibles)
	# First, do a linear search for a character in possibles that is not already in str.
	for (poss_index = 1; poss_index <= possibles_len; poss_index++) {
		ch = substr(possibles, poss_index, 1)
		x = index(str, ch)
		if (x == 0) {
			# Found one.
			if (poss_index == possibles_len) {
				# The only character in possibles that is not in str was the last
				# character in possibles.  As an optimization, just return it.
				return ch
			}
			# Since we know there are characters in possibles that are not in str,
			# we know the following loop can eventually terminate.
			# Randomly choose characters from possibles until one is found that is
			# not already in str.  
			while ((x = index(str, (ch = substr(possibles, get_random_int(possibles_len), 1)))) != 0) {
				;
			}
			return ch
		}
	}
	return ""
}

function calculate_seed() {
    cmd = "date +%s"
    cmd | getline tm
    close(cmd)
    cmd2 = "ps -e -o pid | tail -n 1" 
    cmd2 | getline pid
    close(cmd2)
    seed_tm_pid = ((tm + pid) * 3)

    if(debug) {
        printf("%s: tm: %ld, pid: %ld, ((tm+pid)*3): %ld\n", identification, tm, pid, seed_tm_pid)
    }

    return(seed_tm_pid)
}

# Scramble the characters in a string.
function scramble(str) {
	# Randomly choose and concatenate characters from str until all have been chosen.
	scrambled = ""
	while((ch = get_random_unique_character(scrambled, str)) != "") {
		scrambled = scrambled ch
	}
	return scrambled
}

# end of make_password.awk
