/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// FUNCTIONS
def rmNonMultiFastAs(ch_fastas, min) {
    def ch_nonempty_fastas = ch_fastas
        .filter { _meta, fasta ->
            try {
                file(fasta).countFasta( limit: min ) > (min - 1)
            } catch (java.util.zip.ZipException e) {
                log.debug "[rmNonMultiFastAs]: ${fasta} is not in GZIP format, this is likely because it was cleaned with --remove_intermediate_files"
                true
            } catch (EOFException) {
                log.debug "[rmNonMultiFastAs]: ${fasta} has an EOFException, this is likely an empty gzipped file."
                false
            }
        }
    return ch_nonempty_fastas
}

// MODULES
include { DIPPER_UNALIGNED  } from '../../../modules/local/dipper/unaligned'
include { UHVDB_TAXASPLIT   } from '../../../modules/local/uhvdb/taxasplit'
// SUBWORKFLOWS
include { AAICLUSTER    } from '../../../subworkflows/local/aaicluster'
// include { ANICLUSTER } from '../../../subworkflows/anicluster'

workflow COMPARE {

    take:
    virus_fna_gz            // channel: [ [ meta ], unique_virus.fna.gz ]
    split_virus_fna_gz      // channel: [ [ meta ], unique_virus.part_*.fna.gz ]
    virus_summary_tsv_gz    // channel: [ [ meta ], virus_summary.tsv.gz ]

    main:

    //-------------------------------------------
    // MODULE: UHVDB_TAXASPLIT
    // inputs:
    // - [ [ meta ], unique_virus.fna.gz ]
    // - [ [ meta ], virus_summary.tsv.gz ]
    // outputs:
    // - [ [ meta ], unique_virus.taxa*.fna.gz ]
    // steps:
    // - Split fasta by taxa (script)
    // - Cleanup (script)
    //-------------------------------------------
    UHVDB_TAXASPLIT(
        virus_fna_gz,
        virus_summary_tsv_gz
    )
    ch_taxa_split_fna_gz = rmNonMultiFastAs(
        UHVDB_TAXASPLIT.out.fna_gzs
            .map { _meta, fna_gzs -> fna_gzs }
            .flatten()
            .map { fna_gz ->
                def taxa = fna_gz.getBaseName().toString() =~ /taxa([^\.]+)\.fna/
                [ [ id: fna_gz.getBaseName(), taxa: taxa[0][1] ], fna_gz ]
            },
            2
    )

    //-------------------------------------------
    // SUBWORKFLOW: ANICLUSTER
    // inputs:
    // - [ [ meta ], virus.unique.fna.gz ]
    // - uhvdb_dir
    // outputs:
    // - [ [ meta ], clusters.tsv.gz ]
    // - [ [ meta ], dedup_reps.fna.gz ]
    // - [ [ meta ], genomovar_reps.fna.gz ]
    // - [ [ meta ], species_reps.fna.gz ]
    // - [ [ meta ], species_reps.faa.gz ]
    // - [ [ meta ], species_graph.txt.gz ]
    // steps:
    // - SEQHASHER (module)
    //-------------------------------------------
    if (params.run_anicluster) {
        // ANICLUSTER(
        //     ch_taxa_split_fna_gz,
        //     uhvdb_dir
        // )
        // ch_anicluster_reps_fna_gz = ANICLUSTER.out.species_reps_fna_gz
    } else {
        ch_anicluster_reps_fna_gz   = ch_taxa_split_fna_gz
    }

    //-------------------------------------------
    // SUBWORKFLOW: AAICLUSTER
    // inputs:
    // - [ [ meta ], species_reps.faa.gz ]
    // - uhvdb_dir
    // outputs:
    // - [ [ meta ], clusters.tsv.gz ]
    // - [ [ meta ], family_graph.txt.gz ]
    // steps:
    // - SEQHASHER (module)
    //-------------------------------------------
    if (params.run_aaicluster) {
        AAICLUSTER(
            ch_anicluster_reps_fna_gz
        )
    }

    //-------------------------------------------
    // MODULE: DIPPER_UNALIGNED
    // inputs:
    // - [ [ meta ], unique_virus.taxa*.fna.gz, uhvdb.taxa*.nwk.gz ]
    // outputs:
    // - [ [ meta ], clusters.tsv.gz ]
    // - [ [ meta ], family_graph.txt.gz ]
    // steps:
    // - Create tree (script)
    // - Compress (script)
    //-------------------------------------------
    if (params.run_phylogeny) {
        if (file("${params.uhvdb_dir}/*.nwk.gz").isEmpty()) {
            log.warn "UHVDB Newick tree does not exist: ${params.uhvdb_dir}/uhvdb.nwk.gz"
            log.warn "Creating de novo phylogeny."
            ch_dipper_input = ch_taxa_split_fna_gz.map { meta, fna_gz -> [ meta, fna_gz, [] ] }
        } else {
            ch_dipper_input = ch_taxa_split_fna_gz.map { meta, fna_gz -> [ meta, fna_gz, [] ] }
        }
        DIPPER_UNALIGNED(
            ch_dipper_input
        )
    }

    // emit:
    // nwk_gz = DIPPER_UNALIGNED.out.nwk_gz
}
