using System;
using System.Web;

using Sitecore.StringExtensions;

/// <summary>
/// Summary description for Class1
/// </summary>
public partial class SitecoreDiagPage: System.Web.UI.Page
{
  public static class Trace
  {
    public static void Info(string msg)
    {
      HttpContext.Current.Response.Write(Format(msg, "green"));
    }
    public static void Warn(string msg)
    {
      HttpContext.Current.Response.Write(Format(msg, "orange"));
    }
    public static void Err(string msg)
    {
      HttpContext.Current.Response.Write(Format(msg, "red"));
    }

    public static void Clicker(Clicker clicker)
    {
      Info("STATS: TotalProcessed: '{0}'; Warnings: '{1}'; Errors: '{2}'".FormatWith(clicker.TotalProcessed, clicker.Warnings, clicker.Errors));
    }

    private static string Format(string msg, string cssMarkerColor)
    {
      return "<div style='display:table;'><span style='display:table-cell;background-color:{0}'>&nbsp;</span><code display:'table-cell;'><pre>{1}</pre></code></div>".FormatWith(cssMarkerColor, msg);
    }
  }

  public class Clicker
  {
    public int TotalProcessed { get; private set; }
    public int Warnings { get; private set; }
    public int Errors { get; private set; }

    public void Err() { this.Errors += 1; }
    public void Warn() { this.Warnings += 1; }
    public void Click() { this.TotalProcessed += 1; }
  }
}
