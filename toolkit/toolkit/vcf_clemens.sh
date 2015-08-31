#!/usr/bin/env sh
#jje16, msl34 01192015
#vcf hack process for clemens (classically) vcf merge, hgvs,
#output is a vcf expanded into a table, info name as header, 
# with the added sample field ZY=het/hom interpreted from gatk GT
set -e

##usage
if [ "$1" = "" ]; then
	echo "usage vcf_clemens.sh run_directory_path"
	exit
fi


##dir with raw gatk vcfs
DIR=$1


 ##clean hidden chars, add qd, fs from info to sample col
 #all clean, formtoinfo qd, formtoinfo fs in one command


#!!!!
#fix: sleep not enough after adding qd, extended to 360
ls $DIR/*.vcf | perl -ne 'chomp;my $out=$_.".clean";my $cmd="bsub -q pcpgmwgs -n 1 -R \"rusage[mem=4000]\" -o out.out -e err.err \"cat $_ \| clean_hidden.pl \| stdin_to_file.pl $out\"";print $cmd."\n";system($cmd)' && sleep 600 && ls $DIR/*.clean | perl -ne 'chomp;my $out=$_.".qd";my $cmd="bsub -q pcpgmwgs -n 1 -R \"rusage[mem=4000]\" -o out.out -e err.err \"vcf_info_to_format.pl $_ QD \| stdin_to_file.pl $out\"";print $cmd."\n";system($cmd)' && sleep 600 && ls $DIR/*.qd | perl -ne 'chomp;my $out=$_.".fs.vcf";my $cmd="bsub -q pcpgmwgs -n 1 -R \"rusage[mem=4000]\" -o out.out -e err.err \"vcf_info_to_format.pl $_ FS \| stdin_to_file.pl $_.fs.vcf\"";print $cmd."\n";system($cmd)'

sleep 600


##merge
#bgzip, tabix and vcf-merge
#from each plate dir, cp raw/*.clean.qd.fs.vcf to dir merge/prep
#not sure whether tabix needs "-h" to add header or no
ls $DIR/*.qd.fs.vcf | perl -ne 'chomp;system("bgzip ".$_);'

ls $DIR/*.qd.fs.vcf.gz | perl -ne 'chomp;system("tabix -h ".$_);'

vcf-merge `ls $DIR/*.qd.fs.vcf.gz` > $DIR/all.merge.vcf


##hgvs
#rm chr
cat $DIR/all.merge.vcf | perl -ne 's/^chr//;print;' > $DIR/all.merge.nochr.vcf

vcf_to_gi_hgvs.sh $DIR/all.merge.nochr.vcf > $DIR/hgvs.tbl

#zygosity
zygos_bool.pl $DIR/all.merge.nochr.vcf > $DIR/merge_zygo.vcf

#!!!check if... doesn't seem to have gatk 0/1 sample value, wrong num col


##combine hgvs table and zygo vcf
#cat $DIR/merge_zygo.vcf | perl -ne 'if(/^\#/){print}else{s/\n$;my @col=split(/\t/,$_);my $format=$col[8];my @form=split(/:/,$format);for(my $i=9;$i<@col;$i++){if($col[$i] ne "."){my @newval;my @val=split(/:/,$col[$i]);for(my $j=0;$j<@form;$j++){push(@newval,$form[$j]."=".$val[$j]);}$col[$i]=join(":",@newval);}}print join("\t",@col)."\n";}' > $DIR/merge_zygo_form.vcf

cat $DIR/merge_zygo.vcf | perl -ne 'if(/^\#/){print}else{s/\n$//;my @col=split(/\t/,$_);my $format=$col[8];my @form=split(/:/,$format);for(my $i=9;$i<@col;$i++){if($col[$i] ne "."){my @newval;my @val=split(/:/,$col[$i]);for(my $j=0;$j<@form;$j++){push(@newval,$form[$j]."=".$val[$j]);}$col[$i]=join(":",@newval);}}print join("\t",@col)."\n";}' > $DIR/keyval.vcf


#merge final vcf (zygo) with hgvs tbl

#make common id (including header)


#fix
grep -v '^##' $DIR/keyval.vcf  | perl -ne 'my @arr=split(/\t/,$_);print $arr[0]."|".$arr[1]."|".$arr[3]."\t".$_;' | perl -ne 's/\#CHROM\|POS\|REF/\#variant/ if /\#C/;print' > $DIR/keyval_hgvsid.tbl
#grep -v '^##' $DIR/merge_zygo_hgvs_id.tbl  | perl -ne 'my @arr=split(/\t/,$_);print $arr[0]."|".$arr[1]."|".$arr[3]."\t".$_;' | perl -ne 's/\#CHROM\|POS\|REF/\#variant/ if /\#C/;print' > $DIR/keyval_hgvsid.tbl


tbl_merge.pl $DIR/keyval_hgvsid.tbl $DIR/hgvs.tbl 5 | cut -f2,3,5,7-12,17- | perl -ne 'if(/^\#CHROM/){s/\#CHROM/chrom/;s/POS/pos/;s/REF/ref/;s/alt_allele/alt/;}print;' > $DIR/variant_final.txt

echo "File: variant_final.txt"
echo Done.

exit
