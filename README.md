# HybPipe
Set of bash scripts for analysis of HybSeq raw data. Consists of several steps:  
0. Download FASTQ files from Illumina BaseSpace storage  
1. Processing raw reads (PhiX removal, adaptor removal, quality filtering, summary statistics)  
*  Intermediate manual step - read mapping to 'pseudoreference' in Geneious, export consensus file  
3. Recognize sequences matching probes (generate PSLX files using BLAT)  
4. Create alignments for all genes  
5. Treat missing data, select best genes  
6. Generate FastTree or RAxML gene trees  
7. Root gene trees with outgroup  
8. Estimate species tree (ASTRAL, ASTRID, MP-EST, MRL, concatenation)  
  
Uses many additional software that must be installed and put in the PATH prior tu run scripts.  
Also utilizes many scripts developed by others (located in HybSeqSource folder). PLEASE CITE APPROPRIATELY THOSE SCRIPTS WHEN USING HybPipe!  

