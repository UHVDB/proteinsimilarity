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
include { GENOMAD_DOWNLOADDATABASE  } from './modules/local/genomad/downloaddatabase'
include { GENOMAD_ENDTOEND          } from './modules/local/genomad/endtoend'
include { READ_DOWNLOAD             } from './modules/local/read/download'
include { READ_PREPROCESS           } from './modules/local/read/preprocess'

// SUBWORKFLOWS
// include { GENOMAD                    } from './subworkflows/local/genomad'
include { PREPROCESS    } from './subworkflows/local/preprocess'

// WORKFLOWS
include { ANNOTATE                  } from './workflows/local/annotate'
include { MINE                      } from './workflows/local/mine'

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
    ch_virus_fna_gz         = channel.empty()
    ch_hq_virus_fna_gz      = channel.empty()

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

    // Load input --fastqs
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

    //-------------------------------------
    // Load input --fnas
    //-------------------------------------
    if ( params.fnas ) {
        ch_input_fastas = ch_input_fastas.mix(
            channel.fromPath(params.fastas, size:-1)
            .map { meta, fasta ->
                def meta_new = [:]
                meta_new.id           = meta
                meta_new.group        = meta
                return [ meta_new, [ fasta[0] ] ]
            }
        )
    }

    //-------------------------------------
    // Load input --virus_fnas
    //-------------------------------------
    if ( params.virus_fnas ) {
        ch_input_virus_fastas = ch_input_virus_fastas.mix(
            channel.fromPath(params.ch_input_virus_fastas, size:-1)
            .map { meta, virus_fasta ->
                def meta_new = [:]
                meta_new.id           = meta
                meta_new.group        = meta
                return [ meta_new, [ virus_fasta[0] ] ]
            }
        )
    }

    //-------------------------------------------
    // WORKFLOW: MINE
    // inputs:
    // - [ [ meta ], assembly.fna.gz ]
    // - [ [ meta ], virus.fna.gz ]
    // - [ [ meta ], reads.spring ]
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
    MINE(
        ch_preprocessed_spring,
        ch_input_fastas,
        ch_input_virus_fastas
    )

    if ( params.run_assemble ) {
        // ch_assembly_fna_gz       = MINE.out.assembly_fna_gz
    } else {
        ch_assembly_fna_gz      = ch_input_fastas
    }

    if ( params.run_classify ) {
        // ch_virus_fna_gz          = MINE.out.virus_fna_gz
        // ch_virus_summary_tsv_gz  = MINE.out.virus_summary_tsv_gz
    }  else {
        //
        // MODULE: Download geNomad database
        //
        GENOMAD_DOWNLOADDATABASE()

        //
        // MODULE: Run geNomad end-to-end on input virus sequences
        //
        GENOMAD_ENDTOEND(
            ch_input_virus_fastas,
            GENOMAD_DOWNLOADDATABASE.out.genomad_db.collect()
        )
        ch_virus_summary_tsv_gz = GENOMAD_ENDTOEND.out.summary_tsv_gz
    }

    if ( params.run_filter ) {
        // ch_hq_virus_fna_gz     = MINE.out.hq_virus_fna_gz
        // ch_filter_summary_tsv_gz  = MINE.out.filter_summary_tsv_gz
    }

    //-------------------------------------------
    // WORKFLOW: ANNOTATE
    // inputs:
    // - [ [ meta ], virus.fna.gz ]
    // - [ [ meta ], hq_virus.fna.gz ]
    // - [ [ meta ], virus_summary.tsv.gz ]
    // outputs:
    // - [ [ meta ], crisprhost.tsv.gz ]
    // - [ [ meta ], phisthost.tsv.gz ]
    // - [ [ meta ], tophit.tsv.gz ]
    // - [ [ meta ], taxonomy.tsv.gz ]
    // - [ [ meta ], bakta.gbk.gz ]
    // - [ [ meta ], phrogs.tsv.gz ]
    // - [ [ meta ], empathi.tsv.gz ]
    // - [ [ meta ], lifestyle.tsv.gz ]
    // steps:
    // - CRISPRHOST (subworkflow)
    // - PHIST (subworkflow)
    // - TAXONOMY (subworkflow)
    // - FUNCTION (subworkflow)
    // - LIFESTYLE (subworkflow)
    //--------------------------------------------
    ANNOTATE(
        ch_input_virus_fastas.mix(ch_virus_fna_gz).mix(ch_hq_virus_fna_gz),
        ch_virus_summary_tsv_gz
    )

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
    // - [ [ meta ], dedup.fna.gz ]
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
    // ANALYZE(
    //     ch_preprocessed_fastq_gz,
    //     ch_uhvdb_dir,
    //     ch_assembly_fna_gz,
    //     ch_virus_summary_tsv_gz
    // )

    //-------------------------------------
    // Compare novel viruses to UHVDB
    //-------------------------------------
    // // Identify viruses in the same family
    // // Create MSA with TWILIGHT
    // // Visualize phylogeny with DIPPER
    // // Create panMAT with PanMan
}
