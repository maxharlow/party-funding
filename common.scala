import scala.util.Try
import scala.collection.immutable.ListMap
import org.joda.time.DateTime
import org.joda.time.format.DateTimeFormat
import org.json4s.{JValue, JString, JBool, JNull}

object Common {

  def tidy(text: String): String = {
    val escaped = escapeCypher(clean(text))
    if (text contains ',') escaped else titlecase(escaped) // attempt to only titlecase sensible things
  }

  def clean(text: String): String = {
    text.filter(_ >= ' ').trim.replaceAll(" +", " ").replaceAll("\\.", "")
  }

  def escapeCypher(text: String): String = {
    text.replaceAll("""[()\[\]\*\\'"]""", """\$0""")
  }

  def titlecase(text: String): String = {
    text.split(" ").map(_.toLowerCase.capitalize).mkString(" ")
  }

  def stripTitles(name: String): String = {
    val cleanName = name.replaceAll("^(na )|( na)", "")
    val prefixes = List("Ms", "Mrs", "Miss", "Mr", "Dr", "Cllr", "Sir", "Dame", "Hon", "The Hon", "Rt Hon", "The Rt Hon")
    val suffixes = List("Deceased", "QC", "MP", "MSP", "AM", "MLA", "MEP", "OBE", "MBE", "CBE")
    val titlesRegex = (prefixes.map("^(" + _ + " )") ++ suffixes.map("( " + _ + ")(,?)")).mkString("|")
    cleanName.replaceAll(titlesRegex, "").replaceAll(titlesRegex, "") // apply it twice for titles such as 'the rt hon sir'
  }

  def nameCheck[A](name: String)(check: String => Try[A]): Try[A] = {
    val names = name.split(" ")
    val middleNames = if (names.length > 2) names.init.tail.toList else Nil

    def shortName = check(names.head + " " + names.last)
    def initalledName = check(names.head + middleNames.map(_.head).mkString(" ") + names.last)
    def initalledDottedName = check(names.head + middleNames.map(_.head).mkString(". ") + names.last)

    val fullNameCheck = check(name)

    if (fullNameCheck.isSuccess) fullNameCheck
    else if (!middleNames.isEmpty) {
      shortName orElse initalledName orElse initalledDottedName
    }
    else fullNameCheck // if all else fails
  }

  def propertise(bind: String, jsonMap: ListMap[String, JValue]): String = {
    val pairs = jsonMap map {
      case (key, JString(value)) if key contains "Date" => s"""\n  $bind.$key=${value.replace("-", "")}"""
      case (key, JString(value)) => s"$bind.$key='${tidy(value)}'"
      case (key, JBool(value)) => s"$bind.$key=${value.toString}"
      case (key, JNull) => ""
      case unexpected => throw new Exception(s"Unexpected Json: $unexpected")
    }
    pairs.filter(!_.isEmpty).mkString(",")
  }

}
