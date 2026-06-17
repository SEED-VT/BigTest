package weblog

import org.apache.spark.rdd.RDD
import utils.SparkProgramTemplate

/**
 * Count ERROR-level events per service from server log lines. Each line packs
 * several ';'-separated events; each event is "service,level,message".
 *
 * Exercises flatMap (one line -> a collection of events, a distinctive BigTest
 * feature), filter on an equals predicate, map, and reduceByKey aggregation.
 */
object weblog extends SparkProgramTemplate {
  def main(args: Array[String]): Unit = {}

  override def execute(input1: RDD[String]): RDD[String] = {
    input1
      .flatMap(line => line.split(";"))
      .filter(e => e.split(",")(1).equals("ERROR"))
      .map(e => (e.split(",")(0), 1))
      .reduceByKey(_ + _)
      .map(t => t._1 + ":" + t._2)
  }
}
