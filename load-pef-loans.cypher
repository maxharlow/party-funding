// identifiers are separate for benefactors and (lenders/donors) and recipients ('entities'), but the same across donations and loans  
CREATE CONSTRAINT ON (benefactor: Benefactor) ASSERT benefactor.benefactorID IS UNIQUE;
CREATE CONSTRAINT ON (recipient: Recipient) ASSERT recipient.recipientID IS UNIQUE;


USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM 'http://github.com/maxharlow/scrape-pef/raw/master/pef-loans.csv' AS record

       MERGE (b: Benefactor {benefactorID: record.lenderID}) ON CREATE SET
              b.lenderType = record.lenderType,
              b.title = record.lenderTitle,
              b.firstName = record.lenderFirstName,
              b.middleName = record.lenderMiddleName,
              b.lastName = record.lenderLastName,
              b.name = ( // if blank, construct
                    CASE WHEN record.lenderName = ''
                    THEN replace(record.lenderFirstName + ' ' + record.lenderMiddleName + ' ' + record.lenderLastName, '  ', ' ')
                    ELSE record.lenderName
                    END
              ),
              b.address = record.lenderAddress,
              b.postcode = record.lenderPostcode,
              b.country = record.lenderCountry

       MERGE (r: Recipient {recipientID: record.recipientID}) ON CREATE SET
              r.name = record.recipientName,
              r.recipientType = record.recipientType,
              r.recipientRegulatedType = record.recipientRegulatedType,
              r.deregisteredDate = record.recipientDeregisteredDate

       CREATE (b)-[:LOANED_TO {
              ecReference: record.ecReference,
              ecLastNotifiedDate: toInt(replace(record.ecLastNotifiedDate, '-', '')),
              ecPublishedDate: toInt(replace(record.ecPublishedDate, '-', '')),
              ecReleaseTitle: record.ecReleaseTitle,
              value: toFloat(replace(record.value, '£', '')), // yes, it's currency represented as floating-point
	      valueRepaid: toFloat(replace(record.valueRepaid, '£', '')),
	      valueConverted: toFloat(replace(record.valueConverted, '£', '')),
	      valueOutstanding: toFloat(replace(record.valueOutstanding, '£', '')),
              type: record.type,
	      rate: record.rate,
	      rateFixed: record.rateFixed,
	      rateVariable: record.rateVariable,
	      status: record.status,
	      repaymentTerm: record.repaymentTerm,
              accountingUnitName: record.accountingUnitName,
              accountingUnitID: record.accountingUnitID,
              startDate: toInt(replace(record.startDate, '-', '')),
              endDate: toInt(replace(record.endDate, '-', '')),
	      repaidDate: toInt(replace(record.repaidDate, '-', '')),
	      referenceNumber: record.referenceNumber,
	      notes: record.notes,
	      additionalInformation: record.additionalInformation,
	      isReportedDueToAggregation: record.isReportedDueToAggregation,
	      areReportingUnitsTreatedAsCentralParty: record.areReportingUnitsTreatedAsCentralParty,
	      hasSecurityBeenGiven: record.hasSecurityBeenGiven
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
      WHERE (has(i.lenderType) AND i.lastName <> '')
      OR (i.recipientType = 'Regulated Donee' AND i.recipientRegulatedType <> 'Members Association')
      SET i:Individual;

// tagging organisations
MATCH (o)
      WHERE (has(o.lenderType) AND o.lastName = '')
      OR o.recipientType = 'Permitted Participant'
      OR o.recipientRegulatedType = 'Members Association'
      SET o:Organisation;

// tagging parties
MATCH (p)
      WHERE p.lenderType = 'Registered Political Party'
      OR p.recipientType = 'Political Party'
      OR p.recipientType = 'Third Party'
      SET p:Party;
