#!/usr/bin/env nextflow

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// PLUGINS
include { samplesheetToList } from 'plugin/nf-schema'

// FUNCTIONS
def validateInputSamplesheet (input) {
    def metas = input[1]

    // Check that multiple runs of the same sample are of the same datatype i.e. single-end / paired-end
    def endedness_ok = metas.collect{ meta -> meta.single_end }.unique().size == 1
    if (!endedness_ok) {
        error("Please check input samplesheet -> Multiple runs of a sample must be of the same datatype i.e. single-end or paired-end: ${metas[0].id}")
    }
    // Check that multiple runs of the same sample are placed in the same group
    def grouping_ok = metas.collect{ meta -> meta.group }.unique().size == 1
    if (!grouping_ok) {
        error("Please check input samplesheet -> Multiple runs of a sample must be placed into the same group: ${metas[0].id}")
    }
    // Check that multiple runs of the same sample are given different run ids
    def runs_ok   = metas.collect{ meta -> meta.run }.unique().size == metas.collect{ meta -> meta.run }.size
    if (!runs_ok) {
        error("Please check input samplesheet -> Multiple runs of a sample must be given a different run id: ${metas[0].id}")
    }
}

// MODULES
include { DEACON_INDEXFETCH         } from './modules/local/deacon/indexfetch'
include { SEQKIT_CONCAT             } from './modules/local/seqkit/concat'
include { UHVDB_CATHEADER           } from './modules/local/uhvdb/catheader'


// SUBWORKFLOWS
include { BAKTA                     } from './subworkflows/local/bakta'
include { UNIQUE                    } from './subworkflows/local/unique'
include { PREPROCESS                } from './subworkflows/local/preprocess'

// WORKFLOWS
// include { ANALYZE                   } from './workflows/local/analyze'
include { ANNOTATE                  } from './workflows/local/annotate'
include { COMPARE                   } from './workflows/local/compare'
include { MINE                      } from './workflows/local/mine'
// include { UPDATE                    } from './workflows/local/update'

//-------------------------------------------
// PIPELINE: UHVDB
// inputs:
// - params.input
// - params.fastqs
// - params.fnas
// - params.virus_fnas
// outputs:
// - params.output_dir
// steps:
// - load inputs (various functions)
// - PREPROCESS_READS (subworkflow)
// - MINE (workflow)
// - ANNOTATE (workflow)
// - UPDATE (workflow)
// - ANALYZE (workflow)
// - COMPARE (workflow)
//-------------------------------------------
workflow {

    main:

    ch_input_fastqs_prefilt = channel.empty()
    ch_input_sra_prefilt    = channel.empty()
    ch_input_fastas         = channel.empty()
    ch_input_virus_fastas   = channel.empty()

    // Load input samplesheet (--input)
    if (params.input) {
        ch_samplesheet = channel.fromList(samplesheetToList(params.input, "${projectDir}/assets/schema_input.json"))
            .map { meta, fastq_1, fastq_2, _fna, _virus_fna ->
                    def sra         = meta.acc
                    meta.single_end = fastq_2 ? false : true
                    def no_fastq    = !fastq_1 && !fastq_2
                    if (meta.single_end) {
                        return [ meta + [ from_sra:false ], [ fastq_1 ], sra ]
                    } else if (!no_fastq) {
                        return [ meta + [ from_sra:false ], [ fastq_1, fastq_2 ], sra ]
                    } else {
                        return [ meta + [ from_sra:true ], [], sra ]
                    }
            }
            .multiMap { meta, fastqs, sra ->
                fastqs: [ meta, fastqs ]
                sra:    [ meta, sra ]
            }

        // validate samplesheet
        ch_samplesheet.fastqs
            .map { meta, fastq ->
                [ meta.id, meta, fastq ]
            }
            .groupTuple()
            .map { samplesheet -> validateInputSamplesheet(samplesheet) }

        ch_input_fastqs_prefilt = ch_input_fastqs_prefilt.mix(ch_samplesheet.fastqs)
        ch_input_sra_prefilt    = ch_input_sra_prefilt.mix(ch_samplesheet.sra)

        ch_input_fastas = ch_input_fastas.mix(
                channel.fromList(samplesheetToList(params.input, "${projectDir}/assets/schema_input.json"))
                .map { meta, _fastq_1, _fastq_2, fna, _virus_fna ->
                    return [ meta, fna ]
                }
                .filter { _meta, fna -> fna[0] }
        )

        ch_input_virus_fastas = ch_input_virus_fastas.mix(
                channel.fromList(samplesheetToList(params.input, "${projectDir}/assets/schema_input.json"))
                .map { meta, _fastq_1, _fastq_2, _fna, virus_fna ->
                    return [ meta, virus_fna ]
                }
                .filter { _meta, virus_fna -> virus_fna[0] }
        )
    }

    // Load fastq input (--fastqs)
    if ( params.fastqs ) {
        ch_input_fastqs_prefilt = ch_input_fastqs_prefilt.mix(
            channel.fromFilePairs(params.fastqs, size:-1)
            .map { meta, fastq ->
                def meta_new = [:]
                meta_new.id           = meta
                meta_new.bioproject   = meta
                meta_new.group        = meta
                meta_new.single_end   = fastq.size() == 1 ? true : false
                meta_new.from_sra     = false
                if ( meta_new.single_end ) {
                    return [ meta_new, [ fastq[0] ] ]
                } else {
                    return [ meta_new, [ fastq[0], fastq[1] ] ]
                }
            }
        )
    }

    // Filter out empty fastq channels
    ch_input_fastqs = ch_input_fastqs_prefilt.filter { _meta, fastqs -> fastqs[0] }
    ch_input_sras   = ch_input_sra_prefilt.filter { _meta, sra -> sra[0] }

    if ( params.run_assemble || params.run_referenceanalyze ) {
        //-------------------------------------------
        // SUBWORKFLOW: PREPROCESS
        // inputs:
        // - [ [ meta ], [ read1.fastq.gz, read1.fastq.gz? ] ]
        // - [ [ meta ], acc ]
        // outputs:
        // - [ [ meta ], spring ]
        // steps:
        // - DEACON_INDEXFETCH (module)
        // - READ_DOWNLOAD (module)
        // - READ_PREPROCESS (module)
        //-------------------------------------------
        PREPROCESS(
            ch_input_fastqs,
            ch_input_sras
        )
        ch_preprocessed_spring = PREPROCESS.out.preprocessed_spring
    }

    //-------------------------------------
    // Load assembly inputs (--fnas)
    //-------------------------------------
    if ( params.fnas ) {
        ch_input_fastas = ch_input_fastas.mix(
            channel.fromPath(params.fnas)
            .map { fasta ->
                def meta    = [:]
                meta.id     = fasta.getBaseName()
                meta.group  = fasta.getBaseName()
                return [ meta, fasta ]
            }
        )
    }

    //-------------------------------------
    // Load virus genome inputs (--virus_fnas)
    //-------------------------------------
    if ( params.virus_fnas ) {
        ch_input_virus_fastas = ch_input_virus_fastas.mix(
            channel.fromPath(params.virus_fnas)
            .map { virus_fasta ->
                def meta    = [:]
                meta.id     = virus_fasta.getBaseName()
                meta.group  = virus_fasta.getBaseName()
                return [ meta, virus_fasta ]
            }
        )
    }

    //-------------------------------------------
    // WORKFLOW: MINE
    // inputs:
    // - [ [ meta ], reads.spring ]
    // - [ [ meta ], assembly.fna.gz ]
    // - [ [ meta ], virus.fna.gz ]
    // outputs:
    // - [ [ meta ], assembly.fna.gz ]
    // - [ [ meta ], virus.fna.gz ]
    // - [ [ meta ], virus_summary.tsv.gz ]
    // - [ [ meta ], hq_virus.fna.gz ]
    // - [ [ meta ], filter_summary.tsv.gz ]
    // steps:
    // - ASSEMBLE (subworkflow)
    // - CLASSIFY (subworkflow)
    // - FILTER (subworkflow)
    //--------------------------------------------
    // TODO: Finish MINE workflow implementation
    if (params.run_assemble || params.run_classify || params.run_filter ) {
        MINE(
            ch_preprocessed_spring,
            ch_input_fastas,
            ch_input_virus_fastas
        )
    }

    if ( params.run_assemble ) {
        // ch_assembly_fna_gz       = MINE.out.assembly_fna_gz.mix(ch_input_fastas)
    } else {
        ch_assembly_fna_gz       = ch_input_fastas
    }

    if ( params.run_classify ) {
        // ch_virus_fna_gz          = MINE.out.virus_fna_gz.map { meta, fna_gz -> [ meta + [ hq: false ], fna_gz ] }
        // ch_virus_split_fna_gz    = MINE.out.virus_split_fna_gz
        // ch_virus_summary_tsv_gz  = MINE.out.summary_tsv_gz
    }  else {
        //-------------------------------------------
        // SUBWORKFLOW: UNIQUE
        // inputs:
        // - [ [ meta ], virus.fna.gz ]
        // outputs:
        // - [ [ meta ], unique_virus.fna.gz ]
        // - [ [ meta ], unique_virus_split.part_*.fna.gz ] 
        // - [ [ meta ], unique_virus_summary.tsv.gz ]
        // steps:
        // - SEQHASHER (module)
        // - UHVDB_UNIQUEHASH (module)
        // - UHVDB_UNIQUESEQ (module)
        // - SEQKIT_CONCAT (module)
        //-------------------------------------------
        UNIQUE(
            ch_input_virus_fastas
        )
        ch_unique_virus_fna_gz    = UNIQUE.out.virus_fna_gz
        ch_split_virus_fna_gz     = UNIQUE.out.virus_split_fna_gz
        ch_virus_summary_tsv_gz   = UNIQUE.out.virus_summary_tsv_gz
    }

    if ( params.run_filter ) {
        // ch_unique_virus_fna_gz   = MINE.out.unique_virus_fna_gz
        // ch_virus_split_fna_gz    = MINE.out.unique_virus_split_fna_gz
        // ch_virus_summary_tsv_gz  = MINE.out.summary_tsv_gz
    }

    //-------------------------------------------
    // WORKFLOW: ANNOTATE
    // inputs:
    // - [ [ meta ], unique_virus.fna.gz ]
    // - [ [ meta ], unique_virus_split.part_*.fna.gz ] 
    // - [ [ meta ], unique_virus_summary.tsv.gz ]
    // outputs:
    // - [ [ meta ], bacphlip.tsv.gz ]
    // - [ [ meta ], bakta.gbk.gz ]
    // - [ [ meta ], bakta.tsv.gz ]
    // - [ [ meta ], crisprhost.tsv.gz ]
    // - [ [ meta ], defensefinder.tsv.gz ]
    // - [ [ meta ], dgrscan.tsv.gz ]
    // - [ [ meta ], empathi.csv.gz ]
    // - [ [ meta ], foldseek.tsv.gz ]
    // - [ [ meta ], interproscan.tsv.gz ]
    // - [ [ meta ], padloc.csv.gz ]
    // - [ [ meta ], pharokka.tsv.gz ]
    // - [ [ meta ], phold.tsv.gz ]
    // - [ [ meta ], phisthost.tsv.gz ]
    // - [ [ meta ], phynteny.tsv.gz ]
    // - [ [ meta ], pseudofinder.gff.gz ]
    // - [ [ meta ], tophit.tsv.gz ]
    // - [ [ meta ], taxonomy.tsv.gz ]
    // steps:
    // - CRISPRHOST (subworkflow)
    // - PHIST (subworkflow)
    // - TAXONOMY (subworkflow)
    // - FUNCTION (subworkflow)
    // - LIFESTYLE (subworkflow)
    //--------------------------------------------
    // TODO: Test taxonomy
    // TODO: Add vcontact3
    if (params.run_crisprhost || params.run_phist || params.run_proteinsimilarity || params.run_function || params.run_lifestyle ) {
        ANNOTATE(
            ch_unique_virus_fna_gz,
            ch_split_virus_fna_gz,
            ch_virus_summary_tsv_gz
        )
    }

    //-------------------------------------------
    // WORKFLOW: COMPARE
    // inputs:
    // - [ [ meta ], virus.unique.fna.gz ]
    // - params.uhvdb_dir
    // outputs:
    // - [ [ meta ], clusters.tsv.gz ]
    // - [ [ meta ], dedup_reps.fna.gz ]
    // - [ [ meta ], genomovar_reps.fna.gz ]
    // - [ [ meta ], species_reps.fna.gz ]
    // - [ [ meta ], species_reps.faa.gz ]
    // - [ [ meta ], species_graph.txt.gz ]
    // - [ [ meta ], family_graph.txt.gz ]
    // - [ [ meta ], phylogeny.nwk.gz ]
    // steps:
    // - ANICLUSTER (subworkflow)
    // - AAICLUSTER (subworkflow)
    // - PHYLOGENY (module)
    //--------------------------------------------
    // TODO: Add anicluster subworkflow
    // TODO: Add aaicluster subworkflow
    if (params.run_anicluster || params.run_aaicluster || params.run_phylogeny ) {
        COMPARE(
            ch_unique_virus_fna_gz,
            ch_split_virus_fna_gz,
            ch_virus_summary_tsv_gz
        )
    }

    //-------------------------------------------
    // WORKFLOW: UPDATE
    // inputs:
    // - [ [ meta ], hq_virus.fna.gz ]
    // - [ [ meta ], filter_summary.tsv.gz ]
    // - params.uhvdb_dir
    // outputs:
    // - [ [ meta ], clusters.tsv.gz ]
    // - [ [ meta ], metadata.tsv.gz ]
    // - [ [ meta ], unique.fna.gz ]
    // - [ [ meta ], dedup_reps.fna.gz ]
    // - [ [ meta ], genomovar_reps.fna.gz ]
    // - [ [ meta ], genomovar_reps.faa.gz ]
    // - [ [ meta ], species_reps.fna.gz ]
    // - [ [ meta ], species_reps.faa.gz ]
    // - [ [ meta ], species_graph.txt.gz ]
    // - [ [ meta ], family_graph.txt.gz ]
    // steps:
    // - ANICLUSTER (subworkflow)
    // - AAICLUSTER (subworkflow)
    //--------------------------------------------
    // TODO: Add update workflow
    // UPDATE(
    //     ch_hq_virus_fna_gz,
    //     ch_filter_summary_tsv_gz
    // )

    //-------------------------------------------
    // WORKFLOW: ANALYZE
    // inputs:
    // - [ [ meta ], reads.spring ]
    // - [ [ meta ], assembly.fna.gz ]
    // - [ [ meta ], virus_summary.tsv.gz ]
    // - params.uhvdb_dir
    // outputs:
    // - [ [ meta ], profile.tsv.gz ]
    // - [ [ meta ], ref_activity.tsv.gz ]
    // - [ [ meta ], assembly_activity.tsv.gz ]
    // - [ [ meta ], instrain_profile.tsv.gz ]
    // - [ [ meta ], instrain_compare.tsv.gz ]
    // steps:
    // - REFERENCEANALYZE (subworkflow)
    // - ASSEMBLYANALYZE (subworkflow)
    //--------------------------------------------
    // TODO: Add assemblyanalyze subworkflow
    // ANALYZE(
    //     ch_preprocessed_fastq_gz,
    //     ch_uhvdb_dir,
    //     ch_assembly_fna_gz,
    //     ch_virus_summary_tsv_gz
    // )

    //-------------------------------------------
    // WORKFLOW: PANGENOME
    // inputs:
    // - [ [ meta ], virus.unique.fna.gz ]
    // - params.uhvdb_taxid
    // - params.uhvdb_dir
    // outputs:
    // - [ [ meta ], taxid.panmat ]
    // steps:
    // - PANMAT (subworkflow)
    // - PPANGGOLIN (subworkflow)
    //--------------------------------------------
    // TODO: Add panmat
    // TODO: Add ppanggolin
}
