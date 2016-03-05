"""Read in the database generated via normalize_it,
tabulate the percent turning out early, within a given category.

Right now it just produces stats for Dems and not Dems:
2010
4.4%  Dem
1.9% !Dem

2012
14.8%  Dem
 7.7% !Dem

2014
7.1%  Dem
3.4% !Dem

"""


import  sqlite3

conn = sqlite3.connect('voters.db')

c = conn.cursor()

def pct_early(intab, condition):
    """What percentage of the given subset were early voters? type is None are filtered out always."""
    dems = [x for x in intab if eval(condition) and x[1] is not None]
    y_dems = sum([x[2] for x in dems if x[1]==u'Y'])
    total_dems = sum([x[2] for x in dems])
    print y_dems/(total_dems+0.0)
    return y_dems/(total_dems+0.0)


# Create table
def get_a_year(yr):
    datatab = c.execute("""select party, ell.ell, count(*) from person, election, ell
        where person.pnumber=ell.pnumber and election.enumber==ell.enumber
        and election.year = """ + str(yr) +
        """ and election.type=='G'
        group by party, ell.ell""")

    elections = []
    for i in datatab:
        elections.append(i)
    return elections

tab=[]
for i in (10, 12, 14):
    elections = get_a_year(i)
    tab.append([i, 
    pct_early(elections, "x[0]==u'DEMOCRATIC'"),
    pct_early(elections, "x[0]!=u'DEMOCRATIC'"),
    pct_early(elections, "x[0]==u'NO PARTY'"),
    pct_early(elections, "x[0]==u'REPUBLICAN'"),
    ])

print tab
