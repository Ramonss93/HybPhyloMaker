#!/bin/bash
#----------------MetaCentrum----------------
#PBS -l walltime=12:0:0
#PBS -l select=1:ncpus=4:mem=4gb:scratch_local=80gb
#PBS -j oe
#PBS -N HybPhyloMaker2_readmapping
#PBS -m abe

#-------------------HYDRA-------------------
#$ -S /bin/bash
#$ -pe mthread 12
#$ -q sThC.q
#$ -cwd
#$ -j y
#$ -N HybPhyloMaker2_readmapping
#$ -o HybPhyloMaker2_readmapping.log

# ********************************************************************************
# *    HybPhyloMaker - Pipeline for Hyb-Seq data processing and tree building    *
# *                   Script 02 - Read mapping using bowtie2/bwa                 *
# *                                   v.1.5.0                                    *
# * Tomas Fer, Dept. of Botany, Charles University, Prague, Czech Republic, 2017 *
# * tomas.fer@natur.cuni.cz                                                      *
# ********************************************************************************

#Complete path and set configuration for selected location
if [[ $PBS_O_HOST == *".cz" ]]; then
	echo -e "\nHybPhyloMaker2 is running on MetaCentrum...\n"
	#settings for MetaCentrum
	#Copy file with settings from home and set variables from settings.cfg
	cp $PBS_O_WORKDIR/settings.cfg .
	. settings.cfg
	. /packages/run/modules-2.0/init/bash
	path=/storage/$server/home/$LOGNAME/$data
	source=/storage/$server/home/$LOGNAME/HybSeqSource
	#Move to scratch
	cd $SCRATCHDIR
	#Add necessary modules
	module add bowtie2-2.2.4
	module add bwa-0.7.15
	#module add bcftools-1.3.1
	module add samtools-1.3
	module add perl-5.10.1
	module add gcc-4.8.4
	module add python34-modules-gcc #adds also kindel
	module add ococo-2016-11
elif [[ $HOSTNAME == compute-*-*.local ]]; then
	echo -e "\nHybPhyloMaker2 is running on Hydra...\n"
	#settings for Hydra
	#set variables from settings.cfg
	. settings.cfg
	path=../$data
	source=../HybSeqSource
	#Make and enter work directory
	mkdir -p workdir02
	cd workdir02
	#Add necessary modules
	module load bioinformatics/bowtie2/2.2.6
	module load bioinformatics/bwa
	module load bioinformatics/samtools/1.3
	module load bioinformatics/ococo/ #???
else
	echo -e "\nHybPhyloMaker2 is running locally...\n"
	#settings for local run
	#set variables from settings.cfg
	. settings.cfg
	path=../$data
	source=../HybSeqSource
	#Make and enter work directory
	mkdir -p workdir02
	cd workdir02
fi

#Setting for the case when working with cpDNA
if [[ $cp =~ "yes" ]]; then
	echo -e "Working with cpDNA\n"
	type="cp"
else
	echo -e "Working with exons\n"
	type="exons"
fi

#Test if 'workdir' exist
if [[ ! $location == "1" ]]; then
	if [ "$(ls -A ../workdir02)" ]; then
		echo -e "Directory 'workdir02' already exists and is not empty. Delete it or rename before running this script again. Exiting...\n"
		rm -d ../workdir02/ 2>/dev/null
		exit 3
	fi
fi

#Test if folders for results exist
if [ -d "$path/$type/21mapped_${mappingmethod}" ] && [[ $mapping =~ "yes" ]]; then
	echo -e "Directory '$path/$type/21mapped_${mappingmethod}' already exists. Delete it or rename before running this script again. Exiting...\n"
	rm -d ../workdir02/ 2>/dev/null
	exit 3
elif [ -d "$path/$type/30consensus" ]; then
	echo -e "Directory '$path/$type/30consensus' already exists. Delete it or rename before running this script again. Exiting...\n"
	rm -d ../workdir02/ 2>/dev/null
	exit 3
fi

#Test data structure
echo -en "Testing input data structure..."
if [ -f "$path/10rawreads/SamplesFileNames.txt" ]; then
	#Copy SamplesFileNames.txt and modify it
	cp $path/10rawreads/SamplesFileNames.txt .
	#Add LF at the end of last line in SamplesFileNames.txt if missing
	sed -i.bak '$a\' SamplesFileNames.txt
	#Delete empty lines from SamplesFileNames.txt (if any)
	sed -i.bak2 '/^$/d' SamplesFileNames.txt
	rm *bak*
	for sample in $(cat SamplesFileNames.txt); do
		if [ $mapping == "yes" ]; then
			if [ ! -d "$path/20filtered/$sample" ]; then #Test if each samples-specific folder exists
				echo -e "Directory $sample does not exist within '20filtered'.\n"
				rm SamplesFileNames.txt
				rm -d ../workdir02/ 2>/dev/null
				exit 3
			else
				if [ ! -f "$path/20filtered/$sample/${sample}-1P_no-dups.fastq" ] || [ ! -f "$path/20filtered/$sample/${sample}-2P_no-dups.fastq" ] || [ ! -f "$path/20filtered/$sample/${sample}-1U" ] || [ ! -f "$path/20filtered/$sample/${sample}-2U" ]; then #Test if filtered FASTQ files exist
					if [ ! -f "$path/20filtered/$sample/${sample}-1P_no-dups.fastq.gz" ] || [ ! -f "$path/20filtered/$sample/${sample}-2P_no-dups.fastq.gz" ] || [ ! -f "$path/20filtered/$sample/${sample}-1U.gz" ] || [ ! -f "$path/20filtered/$sample/${sample}-2U.gz" ]; then #Test if filtered and compressed FASTQ files exist
						echo -e "Appropriate filtered fastq files missing in $sample folder...\n"
						rm SamplesFileNames.txt
						rm -d ../workdir02/ 2>/dev/null
						exit 3
					else
						compressed=yes
					fi
				fi
			fi
		else
			if [ ! -f "$path/$type/21mapped_${mappingmethod}/${sample}.bam" ]; then
				echo -e "$sample.bam does not exist within '$type/21mapped_${mappingmethod}'.\n"
				rm SamplesFileNames.txt
				rm -d ../workdir02/ 2>/dev/null
				exit 3
			fi
		fi
	done
	if [[ $cp =~ "yes" ]]; then
		if [ ! -f "$source/$cpDNACDS" ]; then
			echo -e "'$cpDNACDS' is missing in 'HybSeqSource'. Exiting...\n"
			rm -d ../workdir03/ 2>/dev/null
			exit 3
		else
			cpDNACDS=$(echo $cpDNACDS | cut -d"." -f1)
			if [ ! -f "$source/${cpDNACDS}_with${nrns}Ns_beginend.fas" ]; then
				echo -e "${cpDNACDS}_with${nrns}Ns_beginend.fas does not exist within 'HybSeqSource'. Run HybPhyloMaker0b_preparereference.sh first.\n"
				rm SamplesFileNames.txt
				rm -d ../workdir02/ 2>/dev/null
				exit 3
			fi
		fi
	else
		if [ ! -f "$source/$probes" ]; then
			echo -e "$probes does not exist within 'HybSeqSource'.\n"
			rm SamplesFileNames.txt
			rm -d ../workdir02/ 2>/dev/null
			exit 3
		else
			probes=$(echo $probes | cut -d"." -f1)
			if [ ! -f "$source/${probes}_with${nrns}Ns_beginend.fas" ]; then
				echo -e "${probes}_with${nrns}Ns_beginend.fas does not exist within 'HybSeqSource'. Run HybPhyloMaker0b_preparereference.sh first.\n"
				rm SamplesFileNames.txt
				rm -d ../workdir02/ 2>/dev/null
				exit 3
			fi
		fi
	fi
else
	echo -e "List of samples (SamplesFileNames.txt) is missing. Should be in 10rawreads...\n"
	rm -d ../workdir02/ 2>/dev/null
	exit 3
fi
echo -e "OK for running HybPhyloMaker2\n"

#Make a new folder for results
mkdir -p $path/$type

#Copy pseudoreference
if [[ $cp =~ "yes" ]]; then
	probes=$cpDNACDS
fi
probes=$(echo $probes | cut -d"." -f1)
cp $source/${probes}_with${nrns}Ns_beginend.fas .

#Make a new folder for results
if [ ! -d "$path/$type/21mapped_${mappingmethod}" ]; then
	mkdir $path/$type/21mapped_${mappingmethod}
fi

#Make index from pseudoreference
if [[ $mapping =~ "yes" ]]; then
	if [[ $mappingmethod =~ "bowtie2" ]]; then
		echo -en "Indexing pseudoreference for bowtie2..."
		bowtie2-build ${probes}_with${nrns}Ns_beginend.fas pseudoreference.index 1>indexing_pseudoreference.log
		cp indexing_pseudoreference.log $path/$type/21mapped_bowtie2/
	else
		echo -en "Indexing pseudoreference for bwa...\n"
		bwa index ${probes}_with${nrns}Ns_beginend.fas 2>indexing_pseudoreference.log
		cp indexing_pseudoreference.log $path/$type/21mapped_bwa/
	fi
fi

#Copy list of samples
cp $path/10rawreads/SamplesFileNames.txt .

#Creating a summary table
#Produce tab-separated table
#Write headers (number of reads, nr paired reads, nr forward unpaired reads, nr reverse unpaired reads, nr mapped reads, % of mapped reads)
echo -e "Sample no.\tGenus\tSpecies\tTotal nr. reads\tNr. paired reads\tNr. forward unpaired reads\tNr. reverse unpaired reads\tNr. mapped reads\tPercentage of mapped reads" > mapping_summary.txt

#A loop to process all samples in folders named as specified in SamplesFileNames.txt
numberfiles=$(cat SamplesFileNames.txt | wc -l)
calculating=0
for file in $(cat SamplesFileNames.txt); do
	calculating=$((calculating + 1))
	echo -e "\nProcessing sample $file ($calculating out of $numberfiles)"
	
	#sensitive mapping
	if [[ $mapping =~ "yes" ]]; then
		if [[ $compressed =~ "yes" ]]; then
			suffix=".gz"
			#copy fastq.gz files and count number of reads
			cp $path/20filtered/${file}/${file}-1P_no-dups.fastq.gz .
			nr1P=$(gunzip -c ${file}-1P_no-dups.fastq.gz | awk '{s++}END{print s/4}')
			cp $path/20filtered/${file}/${file}-2P_no-dups.fastq.gz .
			nr2P=$(gunzip -c ${file}-2P_no-dups.fastq.gz | awk '{s++}END{print s/4}')
			cp $path/20filtered/${file}/${file}-1U.gz .
			nr1U=$(gunzip -c ${file}-1U.gz | awk '{s++}END{print s/4}')
			cp $path/20filtered/${file}/${file}-2U.gz .
			nr2U=$(gunzip -c ${file}-2U.gz | awk '{s++}END{print s/4}')
		else
			suffix=""
			cp $path/20filtered/${file}/${file}-1P_no-dups.fastq .
			nr1P=$(awk '{s++}END{print s/4}' ${file}-1P_no-dups.fastq)
			cp $path/20filtered/${file}/${file}-2P_no-dups.fastq .
			nr2P=$(awk '{s++}END{print s/4}' ${file}-2P_no-dups.fastq)
			cp $path/20filtered/${file}/${file}-1U .
			nr1U=$(awk '{s++}END{print s/4}' ${file}-1U)
			cp $path/20filtered/${file}/${file}-2U .
			nr2U=$(awk '{s++}END{print s/4}' ${file}-2U)
		fi
		if [[ $mappingmethod =~ "bowtie2" ]]; then
			echo "Mapping using bowtie2..."
			#Bowtie2 parameters are derived from --very-sensitive-local
			#set parameters for mapping using bowtie2
			score=G,20,8
			bowtie2 --local -D 20 -R 3 -N 0 -L 10 -i S,1,0.50 --score-min $score -x pseudoreference.index -1 ${file}-1P_no-dups.fastq${suffix}  -2 ${file}-2P_no-dups.fastq${suffix} -U ${file}-1U${suffix},${file}-2U${suffix} -S ${file}.sam 2>${file}_bowtie2_out.txt
		else
			echo "Mapping pair-end reads using bwa..."
			bwa mem ${probes}_with${nrns}Ns_beginend.fas ${file}-1P_no-dups.fastq${suffix} ${file}-2P_no-dups.fastq${suffix} > ${file}_paired.sam 2>${file}_bwa_out.txt
			echo "Mapping orphaned reads using bwa..."
			if [[ $compressed =~ "yes" ]]; then
				gunzip ${file}-1U.gz
				gunzip ${file}-2U.gz
			fi
			cat ${file}-1U ${file}-2U > ${file}-unpaired
			bwa mem ${probes}_with${nrns}Ns_beginend.fas ${file}-unpaired > ${file}_unpaired.sam 2>>${file}_bwa_out.txt
		fi
		#create BAM from SAM
		echo "Converting to BAM..."
		if [[ $mappingmethod =~ "bowtie2" ]]; then
			samtools view -bS -o ${file}.bam ${file}.sam 2>/dev/null
			rm ${file}.sam
		else
			samtools view -bS -o ${file}_paired.bam ${file}_paired.sam 2>/dev/null
			samtools view -bS -o ${file}_unpaired.bam ${file}_unpaired.sam 2>/dev/null
			samtools merge ${file}.bam ${file}_paired.bam ${file}_unpaired.bam 2>/dev/null
			rm ${file}_paired.sam ${file}_unpaired.sam ${file}_paired.bam ${file}_unpaired.bam
		fi
		#number of mapped reads in BAM
		nrmapped=$(samtools view -F 0x04 -c ${file}.bam)
		#number of all reads in BAM
		nrall=$(samtools view -c ${file}.bam)
		#calculate percentage of mapped reads
		percmapped=$(echo -e "scale=5;100 * ($nrmapped / $nrall)" | bc)
		#extracting header data
		number=$(cut -d'_' -f2 <<< $file | sed 's/S//')
		genus=$(cut -d'-' -f1 <<< $file)
		species=$(cut -d'_' -f1 <<< $file | cut -d'-' -f2)
		#adding data to table
		echo -e "$number\t$genus\t$species\t$nrall\t$nr1P\t$nr1U\t$nr2U\t$nrmapped\t$percmapped" >> mapping_summary.txt
		#copy results to home
		cp ${file}.bam $path/$type/21mapped_${mappingmethod}
		cp ${file}_${mappingmethod}_out.txt $path/$type/21mapped_${mappingmethod}
		cp mapping_summary.txt $path/$type/21mapped_${mappingmethod}
	else
		echo "Copying BAM..."
		cp $path/$type/21mapped_${mappingmethod}/${file}.bam .
	fi
	#CONSENSUS USING KINDEL/OCOCO
	if [[ $conscall =~ "ococo" ]]; then
		echo "Making consensus with OCOCO..."
		ococo -i ${file}.bam -x ococo64 -c $mincov -F ${file}.fasta 2>/dev/null
	else
		echo "Making consensus with kindel..."
		kindel -m $mincov -t $majthres ${file}.bam > ${file}.fasta
	fi
	#change name in fasta file
	sed -i.bak '1d' ${file}.fasta #delete first line
	echo ">$file" > header.txt
	cat header.txt ${file}.fasta > tmp && mv tmp ${file}.fasta
	rm header.txt
	#Remove line breaks from fasta file
	awk '!/^>/ { printf "%s", $0; n = "\n" } /^>/ { print n $0; n = "" } END { printf "%s", n }' ${file}.fasta > tmp && mv tmp ${file}.fasta
	#put $nrns Ns to variable 'a' and $nrns ?s to variable 'b'
	a=$(printf "%0.sN" $(seq 1 $nrns))
	b=$(printf "%0.s?" $(seq 1 $nrns))
	#replace all Ns separating exons by '?'
	sed -i.bak "s/$a/$b/g" ${file}.fasta
	#copy results to home
	cp ${file}.fasta $path/$type/21mapped_${mappingmethod}
	#delete BAM
	rm ${file}.bam
done

#Combine all fasta file into one
cat *.fasta > consensus.fasta
#Remove line breaks from fasta file
awk '!/^>/ { printf "%s", $0; n = "\n" } /^>/ { print n $0; n = "" } END { printf "%s", n }' consensus.fasta > tmp && mv tmp consensus.fasta
mkdir -p $path/$type/30consensus
if [[ $cp =~ "yes" ]]; then
	mv consensus.fasta consensus_cpDNA.fasta
	cp consensus_cpDNA.fasta $path/$type/30consensus
else
	cp consensus.fasta $path/$type/30consensus
fi

#Clean scratch/work directory
if [[ $PBS_O_HOST == *".cz" ]]; then
	#delete scratch
	if [[ ! $SCRATCHDIR == "" ]]; then
		rm -rf $SCRATCHDIR/*
	fi
else
	cd ..
	rm -r workdir02
fi

echo -e "\nScript HybPhyloMaker2 finished...\n"
