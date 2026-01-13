#!/usr/bin/env python

import argparse

import polars as pl

def parse_args(args=None):
    description = "Combine functional annotations across tool outputs."
    epilog = "Example usage: python combine_functions.py --help"

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "-b",
        "--bakta",
        help="Path to TSV file output by Bakta.",
    )
    parser.add_argument(
        "-f",
        "--foldseek",
        help="Path to TSV file output by Foldseek.",
    )
    parser.add_argument(
        "-p",
        "--pharokka",
        help="Path to TSV file output by Pharokka.",
    )
    parser.add_argument(
        "-l",
        "--phold",
        help="Path to TSV file output by Phold.",
    )
    parser.add_argument(
        "-y",
        "--phynteny",
        help="Path to TSV file output by Phynteny.",
    )
    parser.add_argument(
        "-d",
        "--defensefinder",
        help="Path to TSV file output by DefenseFinder.",
    )
    parser.add_argument(
        "-c",
        "--padloc",
        help="Path to TSV file output by PADLOC.",
    )
    parser.add_argument(
        "-o",
        "--output",
        help="Prefix for output TSV files.",
    )
    parser.add_argument('--version', action='version', version='1.0.0')
    return parser.parse_args(args)



def main(args=None):
    args = parse_args(args)

    # load Bakta TSV
    bakta = (
        pl.read_csv(args.bakta, separator='\t', skip_rows=5)
            .rename({'#Sequence Id': 'Sequnce Id'})
    )

    # load foldseek TSV
    try:
        foldseek = (
            pl.read_csv(args.foldseek, separator='\t', has_header=False,
                new_columns=["Locus Tag" , "Foldseek Reference", "Foldseek Identity", "Foldseek Align Length", "mismatch", "gapopen", "qstart", "qend", "tstart", "tend", "Foldseek E-value", "Foldseek Bitscore"]
            )
            .drop(['mismatch', 'gapopen', 'qstart', 'qend', 'tstart', 'tend'])
        )
    except pl.exceptions.NoDataError:
        foldseek = pl.DataFrame({'Locus Tag': [], 'Foldseek Reference': [], 'Foldseek Identity': [], 'Foldseek Align Length': [], 'Foldseek E-value': [], 'Foldseek Bitscore': []})

    # combine Bakta and foldseek
    bakta_foldseek = bakta.join(foldseek, on='Locus Tag', how='left')
    bakta_foldseek.write_csv(f"{args.output}.uniprot.tsv", separator='\t')

    # load pharokka TSV
    pharokka = (
        pl.read_csv(args.pharokka, separator='\t', 
            columns=['gene', 'pyhmmer_bitscore', 'pyhmmer_evalue', 'phrog', 'annot', 'category']
        )
        .rename({
            'gene': 'Locus Tag', 'phrog': 'Pharokka Phrog', 'annot': 'Pharokka Annotation',
            'pyhmmer_bitscore':'Pharokka Bitscore', 'pyhmmer_evalue':'Pharokka E-value',
            'category': 'Pharokka Category'
        })
    )

    # load phold TSV
    phold = (
        pl.read_csv(args.phold, separator='\t', 
            columns=['cds_id', 'phrog', 'function', 'product', 'annotation_method', 'annotation_confidence', 'bitscore', 'fident', 'evalue', 'prostt5_confidence']
        )
        .filter(~pl.col('annotation_method').is_in(['pharokka', 'none']))
        .rename({
            'cds_id':'Locus Tag', 'phrog':'Phold Phrog', 'function':'Phold Category',
            'product':'Phold Annotation', 'annotation_method':'Annotation Method',
            'annotation_confidence':'Annotation Confidence', 'bitscore':'Phold bitscore',
            'fident':'Phold fident', 'evalue':'Phold evalue', 'prostt5_confidence':'ProstT5 Confidence'
        })
        .drop(['Annotation Method'])
    )

    # load phynteny TSV
    phynteny = (
        pl.read_csv(args.phynteny, separator='\t', 
            columns=['ID', 'phrog_id', 'phynteny_category', 'phynteny_confidence']
        )
        .rename({
            'ID':'Locus Tag', 'phrog_id':'Phynteny Phrog',
            'phynteny_category':'Phynteny Category', 'phynteny_confidence':'Phynteny Confidence'
        })
    )

    # combine phrog annotations
    phrogs = pharokka.join(phold, on='Locus Tag', how='left').join(phynteny, on=['Locus Tag'], how='left')
    phrogs.write_csv(f"{args.output}.phrogs.tsv", separator='\t')

    # load padloc CSV
    padloc = (
        pl.read_csv(args.padloc,
            columns=[
                'system.number', 'seqid', 'system', 'target.name', 'hmm.accession', 'hmm.name',
                'protein.name', 'full.seq.E.value', 'domain.iE.value', 'target.coverage', 'hmm.coverage',
                'start', 'end', 'strand', 'target.description', 'relative.position', 'contig.end', 'all.domains',
                'best.hits'
            ]
        )
        .drop([
            'seqid', 'hmm.accession', 'hmm.name', 'start', 'end', 'target.description', 'strand',
            'relative.position', 'all.domains', 'best.hits', 'contig.end'
        ])
        .rename({
            'system.number': 'PADLOC System Number', 'system':'PADLOC System', 'target.name':'Locus Tag',
            'full.seq.E.value':'PADLOC Full E-value', 'domain.iE.value':'PADLOC Domain E-value',
            'target.coverage':'PADLOC Query Coverage', 'hmm.coverage':'PADLOC HMM Coverage',
        })
    )

    # load dbapis
    dbapis = (
        pl.read_csv(args.pharokka, separator='\t', 
            columns=['gene', 'custom_hmm_id', 'custom_hmm_bitscore', 'custom_hmm_evalue']
        )
        .rename({
            'gene': 'Locus Tag', 'custom_hmm_id': 'dbAPIs ID',
            'custom_hmm_bitscore':'dbAPIs Bitscore', 'custom_hmm_evalue':'dbAPIs E-value'
        })
    )

    # load defensefinder TSV
    defensefinder = (
        pl.read_csv(args.defensefinder, separator='\t',
            columns=[
                'hit_id', 'gene_name', 'sys_wholeness', 'sys_score', 'hit_status', 'hit_i_eval', 'hit_score', 'type', 'subtype', 'activity'
            ]
        )
        .rename({
            'hit_id': 'Locus Tag', 'gene_name':'DefenseFinder Reference', 'sys_wholeness':'DefenseFinder System Wholeness', 'hit_status':'DefenseFinder Hit Status',
            'hit_i_eval':'DefenseFinder E-value', 'hit_score':'DefenseFinder Bitscore', 'type':'DefenseFinder Type',
            'subtype':'DefenseFinder Subtype', 'activity':'DefenseFinder Activity'
        })
    )

    # combine defense annotations
    defense = padloc.join(defensefinder, on='Locus Tag', how='full').join(dbapis, on='Locus Tag', how='full')
    defense.write_csv(f"{args.output}.defense.tsv", separator='\t')

if __name__ == "__main__":
    main()
