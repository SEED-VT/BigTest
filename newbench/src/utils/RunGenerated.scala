package utils

import org.apache.spark.rdd.RDD
import org.apache.spark.{SparkConf, SparkContext}
import java.io.File

import movie1._
import transit._
import credit._
import airport._
import usedcars._
import gradebook._
import commutetrips._

/**
 * Runs a benchmark program on a directory of BigTest-generated data files
 * (produced by tools/smt_to_data.py), using the exact same loading contract as
 * utils.TestSuite (skip the header line, append ", " to each row). This proves
 * the generated data files are directly consumable by the actual Spark jobs.
 *
 *   java -cp bin:$CLASSPATH utils.RunGenerated <mnemonic> <pathDir> <numInputs>
 */
object RunGenerated {
  def read(filepath: String, sc: SparkContext): RDD[String] = {
    if (new File(filepath).exists())
      sc.textFile(filepath).zipWithIndex().filter(_._2 > 0).map(_._1 + ", ")
    else
      sc.emptyRDD[String]
  }

  def prog(name: String): SparkProgramTemplate = name match {
    case "movie1"       => movie1
    case "transit"      => transit
    case "credit"       => credit
    case "airport"      => airport
    case "usedcars"     => usedcars
    case "gradebook"    => gradebook
    case "commutetrips" => commutetrips
    case other          => throw new RuntimeException("unknown benchmark: " + other)
  }

  def main(args: Array[String]): Unit = {
    if (args.length < 3) {
      System.err.println("usage: RunGenerated <mnemonic> <pathDir> <numInputs>")
      System.exit(2)
    }
    val mnemonic = args(0)
    val dir = args(1)
    val n = args(2).toInt

    val conf = new SparkConf().setMaster("local[*]").setAppName("RunGenerated")
    val sc = new SparkContext(conf)
    sc.setLogLevel("ERROR")

    val inputs: Array[RDD[String]] = (1 to n).map(i => read(s"$dir/input$i", sc)).toArray

    println(s"=== inputs for $mnemonic ($dir) ===")
    for (i <- 1 to n) {
      println(s"input$i:")
      inputs(i - 1).collect().foreach(r => println("  " + r))
    }

    val out =
      try prog(mnemonic).execute(inputs).map(_.toString).collect()
      catch { case e: Throwable => Array("CRASHED: " + e.getClass.getName + ": " + e.getMessage) }

    println(s"=== output (${out.length} row(s)) ===")
    out.foreach(r => println("  " + r))
    sc.stop()
  }
}
