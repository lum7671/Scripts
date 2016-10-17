#!/usr/bin/env zsh -l

rm -vf TAGS

for src in $(find . -type f);
do
	ETAGS=$(which etags); # /usr/bin/etags;
	case "${src}" in
		*.ad[absm]|*.[CFHMSacfhlmpsty]|*.def|*.in[cs]|*.s[as]|*.src|*.cc|\
			*.hh|*.[chy]++|*.[ch]pp|*.[chy]xx|*.pdb|*.[ch]s|*.[Cc][Oo][Bb]|\
			*.[eh]rl|*.f90|*.for|*.java|*.[cem]l|*.clisp|*.lisp|*.[Ll][Ss][Pp]|\
			[Mm]akefile*|*.pas|*.[Pp][LlMm]|*.psw|*.lm|*.pc|*.prolog|*.oak|\
			*.p[sy]|*.sch|*.scheme|*.[Ss][Cc][Mm]|*.[Ss][Mm]|*.bib|*.cl[os]|\
			*.ltx|*.sty|*.TeX|*.tex|*.texi|*.texinfo|*.txi|*.x[bp]m|*.yy|\
			*.[Ss][Qq][Ll])
			${ETAGS} -a "${src}";
			# echo ${ETAGS}
			;;
		*)
			FTYPE=`file ${src}`;
			case "${FTYPE}" in
				*script*text*)
					${ETAGS} -a "${src}";
					;;
				*text*)
					if head -n1 "${src}" | grep '^#!' >/dev/null 2>&1;
					then
						${ETAGS} -a "${src}";
					fi;
					;;
			esac;
			;;
	esac;
done;
