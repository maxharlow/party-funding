// identifiers are separate for benefactors and (lenders/donors) and recipients ('entities'), but the same across donations and loans
CREATE CONSTRAINT ON (benefactor: Benefactor) ASSERT benefactor.benefactorID IS UNIQUE;
CREATE CONSTRAINT ON (recipient: Recipient) ASSERT recipient.recipientID IS UNIQUE;


USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM 'http://github.com/maxharlow/scrape-pef/raw/master/pef-donations.csv' AS record

       MERGE (b: Benefactor {benefactorID: record.donorID}) ON CREATE SET
              b.donorType = record.donorType,
              b.title = record.donorTitle,
              b.firstName = record.donorFirstName,
              b.middleName = record.donorMiddleName,
              b.lastName = record.donorLastName,
              b.name = ( // if blank, construct
                    CASE WHEN record.donorName = ''
                    THEN replace(record.donorFirstName + ' ' + record.donorMiddleName + ' ' + record.donorLastName, '  ', ' ')
                    ELSE record.donorName
                    END
              ),
              b.companyNumber = record.donorCompanyNumber,
              b.address = record.donorAddress,
              b.postcode = record.donorPostcode,
              b.country = record.donorCountry

       MERGE (r: Recipient {recipientID: record.recipientID}) ON CREATE SET
              r.name = record.recipientName,
              r.recipientType = record.recipientType,
              r.recipientRegulatedType = record.recipientRegulatedType,
              r.deregisteredDate = record.recipientDeregisteredDate

       CREATE (b)-[:DONATED_TO {
              ecReference: record.ecReference,
              ecReportedDate: toInt(replace(record.ecReportedDate, '-', '')),
              ecPublishedDate: toInt(replace(record.ecPublishedDate, '-', '')),
              ecReleaseTitle: record.ecReleaseTitle,
              value: toFloat(replace(record.value, '£', '')), // yes, it's currency represented as floating-point
              type: record.type,
              accountingUnitName: record.accountingUnitName,
              accountingUnitID: record.accountingUnitID,
              receivedDate: toInt(replace(record.receivedDate, '-', '')),
              acceptedDate: toInt(replace(record.acceptedDate, '-', '')),
              returnedDate: toInt(replace(record.returnedDate, '-', '')),
              nature: record.nature,
              purpose: record.purpose,
              notes: record.notes,
              howDealtWith: record.howDealtWith,
              isReportedDueToAggregation: record.isReportedDueToAggregation,
              isReportedUnder6212: record.isReportedUnder6212,
              isSponsorship: record.isSponsorship
       }]->(r)
;


// combine companies that are both benefactors and receipients -- as they have the same number
// MATCH o1, o2
//       WHERE o1 <> o2
//       AND o1:Benefactor
//       AND o2:Recipient
//       AND o1.companyNumber = o2.companyNumber
//       RETURN o1, o2 // todo combine here

// combine individuals that are both benefactors and recipients -- as they have the same name
// MATCH i1, i2
//       WHERE i1 <> i2
//       AND i1:Benefactor
//       AND i2:Recipient
//       AND i1.name = ci.name
//       RETURN i1, i2 // todo combine here


// tagging individuals
MATCH (i)
      WHERE (has(i.donorType) AND i.lastName <> '')
      OR (i.recipientType = 'Regulated Donee' AND i.recipientRegulatedType <> 'Members Association')
      SET i:Individual;

// tagging organisations
MATCH (o)
      WHERE (has(o.donorType) AND o.lastName = '')
      OR o.recipientType = 'Permitted Participant'
      OR o.recipientRegulatedType = 'Members Association'
      SET o:Organisation;

// tagging parties
MATCH (p)
      WHERE p.donorType = 'Registered Political Party'
      OR p.recipientType = 'Political Party'
      OR p.recipientType = 'Third Party'
      SET p:Party;
