package commutetrips

import org.apache.spark.rdd.RDD
import utils.SparkProgramTemplate

/**
 * FSE 2019 paper, Figure 2 — Alice's program that "estimates the total number of
 * trips originated from 'Palms'."  (Gulzar, Mardani, Musuvathi, Kim. White-Box
 * Testing of Big Data Analytics with Complex User-Defined Functions.)
 *
 * Two input tables are joined on a location key:
 *   input1 = trips_table.csv  : id, location, dist, time, ...
 *            speed = dist / time          (cols(3).toInt / cols(4).toInt)
 *   input2 = zipcode_table.csv: name, location, ...
 *
 * After joining trips with the "Palms" zip rows, each trip's speed is classified
 * into car / bus(public) / walk and counted with reduceByKey.
 *
 * This program exercises BigTest's join modeling (both terminating cases — key in
 * only the left or only the right table — and the non-terminating matched case),
 * integer division by zero (cols(4).toInt == 0), and string/segmentation faults
 * (split length, isInteger). BigTest generates concrete trips + zipcode rows that
 * cover each of these joint dataflow/UDF paths.
 */
object commutetrips extends SparkProgramTemplate {
  def main(args: Array[String]): Unit = {}

  override def execute(input1: RDD[String], input2: RDD[String]): RDD[String] = {
    val trips = input1.map { s =>
      val cols = s.split(",")
      (cols(1), cols(3).toInt / cols(4).toInt) // (location, speed)
    }

    val zip = input2
      .map { s =>
        val cols = s.split(",")
        (cols(1), cols(0)) // (location, name)
      }
      .filter(s => s._2.equals("Palms")) // paper writes `== "Palms"`; .equals is the
                                          // decompiler-safe equivalent (Scala `==` emits a
                                          // null-checked BoxesRunTime.equals that jad cannot decompile)

    trips
      .join(zip)
      .map { s =>
        if (s._2._1 > 40) ("car", 1)
        else if (s._2._1 > 15) ("bus", 1)
        else ("walk", 1)
      }
      .reduceByKey(_ + _)
      .map(m => m._1 + ":" + m._2)
  }
}
