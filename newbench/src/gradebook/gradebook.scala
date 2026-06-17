package gradebook

import org.apache.spark.rdd.RDD
import utils.SparkProgramTemplate

/**
 * ICSE 2020 demo paper, Figure 2 — "A Spark program that identifies the courses
 * with less than two failing students."  (Gulzar, Musuvathi, Kim. BigTest: A
 * Symbolic Execution Based Systematic Test Generation Tool for Apache Spark.)
 *
 * A gradebook row is comma separated: courseId:mark, year, studentId, session, major
 *   e.g.  CS233:77,1994,80554313,F1994,CS
 *
 * The program has 17 JDU paths (2 non-terminating, 15 terminating). Testing on the
 * top-100 passing records only exercises 12, missing the three crash-inducing paths
 * around `Integer.parseInt` and the off-by-one bug on line 14 (`<=` should be `<`).
 *
 * BigTest synthesizes inputs such as ":41" / ":0" / "" / non-numeric strings that
 * exercise the remaining paths and reveal both the crash and the predicate fault.
 */
object gradebook extends SparkProgramTemplate {
  def main(args: Array[String]): Unit = {}

  override def execute(input1: RDD[String]): RDD[String] = {
    input1
      .map { line =>
        val arr = line.split(",")
        arr(1)
      }
      .map { l =>
        val a = l.split(":")
        (a(0), Integer.parseInt(a(1)))
      }
      .map { a =>
        if (a._2 > 40)
          ("Pass".concat(a._1), 1)
        else
          ("Fail".concat(a._1), 1)
      }
      .reduceByKey(_ + _)
      .filter(v => v._2 <= 2 && v._1.startsWith("Fail"))
      .map(v => v._1 + "," + v._2)
  }
}
