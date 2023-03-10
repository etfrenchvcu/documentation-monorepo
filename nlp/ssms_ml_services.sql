-- Create output table for NLP results.
drop table if exists note_nlp
create table note_nlp (
	note_id int NOT NULL, 
	mention nvarchar(255),
	[label] nvarchar(255),
	mention_span nvarchar(255),
	sent_span nvarchar(255),
	section nvarchar(255),
	is_negated bit,
	is_family bit,
	sentence nvarchar(max)
)

-- Process documents in batches of 100.
declare @Query nvarchar(max) = N'
	select top 100
		a.Artifact_ID as ROW_ID, 
		lower(a.Content) as TEXT	
	from Notes a
	join Notes_Process b
	  on a.Artifact_ID = b.Artifact_ID
	 and b.Process_Batch_End is null
'

---- Iterate over records that have not yet been processed.
while exists (select top 1 a.Artifact_ID from Notes a left join Notes_Process b on a.Artifact_ID = b.Artifact_ID where b.Artifact_ID is null)
begin
	-- Queue documents for processing
	insert into Notes_Process (Artifact_ID, Process_Batch_Start)
	select top 100 a.Artifact_ID, getdate() from Notes a left join Notes_Process b on a.Artifact_ID = b.Artifact_ID where b.Artifact_ID is null

	-- Results returned from the python script will be inserted into note_nlp.
	insert into note_nlp
	EXECUTE sp_execute_external_script @language = N'Python'
		, @script = N'
#############################################################################
# Configure NLP pipeline
#############################################################################

import medspacy
from medspacy.ner import TargetRule
from medspacy.postprocess import PostprocessingRule, PostprocessingPattern, postprocessing_functions
import pandas as pd
from spacy.tokens import Doc

# spaCy configurations
Doc.set_extension("id", default=None, force=True)

# Instantiate NLP pipeline
nlp = medspacy.load()

# Define rule-based patterns
rules = [
	TargetRule("alcohol", "ALCOHOL", pattern=r"alcohol[a-z]*"),
    TargetRule("drink", "ALCOHOL", pattern=r"dr[aiu]nk"),
    TargetRule("aud", "ALCOHOL", pattern=[{"LOWER": "aud"}]),
	TargetRule("fetal_alcohol", "ALCOHOL", pattern=r"fetal alcohol( syndrome)?"),
	TargetRule("family", "FAMILY", pattern=r"((father)|(mother)|(aunt)|(uncle)|(brother)|(sister)|(sibling)|(cousin))(?![a-rt-z])"),
]
target_matcher = nlp.get_pipe("medspacy_target_matcher")
target_matcher.add(rules)

# Add section detection
sectionizer = nlp.add_pipe("medspacy_sectionizer")

#############################################################################
# Process notes
#############################################################################

def get_batches(arr, batch_size):
	"Yield successive batches from arr."
	for i in range(0, len(arr), batch_size):
		yield arr[i:i+batch_size]

mentions = []
for ix in get_batches(list(InputDataSet.index), batch_size=100):
	# Create batch corpus
	batch = InputDataSet.iloc[ix]
	batch_corpus = [(note.lower(), {"id": id}) for id, note in zip(batch.ROW_ID, batch.TEXT)]

	# Run pipeline on corpus to identify alcohol mentions
	for doc, context in nlp.pipe(batch_corpus, as_tuples=True):
		doc._.id = context["id"] 
		mentions += [(doc._.id, e.text, e.label_, f"{e.start_char}:{e.end_char}", f"{e.sent.start_char}:{e.sent.end_char}", e._.section_category, int(e._.is_negated), int(e._.is_family), e.sent.text.strip()) for e in doc.ents]

output = pd.DataFrame(mentions, columns=["note_id","mention","label","mention_span","sent_span","section","is_negated","is_family","sentence"])

#############################################################################
# Set return dataset
#############################################################################
OutputDataSet = output
	'
		, @input_data_1 = @Query; -- The value returned by @Query is passed to the python script in a pandas dataframe called InputDataSet


	-- Mark queued notes as processed.
	update Notes_Process set Process_Batch_End = getdate() where Process_Batch_End is null;

end