<%@ Page Language="C#" AutoEventWireup="true" Debug="true" CodeFile="Sitecore.DiagPage.cs" Inherits="SitecoreDiagPage" %>

<%@ Import Namespace="Newtonsoft.Json" %>
<%@ Import Namespace="System.Xml" %>
<%@ Import Namespace="Sitecore.ExperienceAnalytics.Aggregation.Data.Model" %>
<%@ Import Namespace="Sitecore.Configuration" %>
<%@ Import Namespace="Sitecore.Diagnostics" %>
<%@ Import Namespace="Sitecore.Xdb.Configuration" %>
<%@ Import Namespace="Sitecore.ExperienceAnalytics.Api" %>
<%@ Import Namespace="Sitecore.StringExtensions" %>

<script runat="server">

  public static class Const
  {
    public static class ExperienceAnalytics
    {
      public static readonly string RdbAggregationSegmentReaderConfig = "/sitecore/experienceAnalytics/client/services/aggregationSegmentReader";
      public static readonly string ScSegmentReader = "/sitecore/experienceAnalytics/client/services/segmentReader";
    }
  }

  public void Page_Load()
  {
    dynamic rdbSegmentReader = Sitecore.Configuration.Factory.CreateObject(Const.ExperienceAnalytics.RdbAggregationSegmentReaderConfig, true);
    Trace.Warn(rdbSegmentReader.GetType().FullName);
    Type rdbSegmentReaderType = rdbSegmentReader.GetType();
    var rdbSegmentReaderGetAll = rdbSegmentReaderType.GetMethod("GetAll", System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Instance);
    IEnumerable<IAggregationSegment> result = rdbSegmentReaderGetAll.Invoke(rdbSegmentReader, new object[] { true });

    foreach (var entry in result) {
      Trace.Info("SegmentID: {0}; DeployDate: {1}".FormatWith(entry.SegmentId, entry.DeployDate.ToString()));
    }
  }

  private void VerifySegments()
  {

    if (!XdbSettings.Enabled)
    {
      Trace.Err("xDB is disabled");
      return;
    }

    /*var segmentDefService = ApiContainer.Repositories.GetSegmentDefinitionService();
    if (segmentDefService == null)
    {
      Response.Write(NoSegmentDefinitionService);
      return;
    }
    
    var segmentRepository = EAC.ClientContainer.Repositories.GetSegmentRepository();
    if (segmentRepository == null)
    {
      Response.Write(NoSegmentRepository);
      return;
    }

    var allSegments = segmentRepository.GetAll();
    var segmentsFromDb = segmentDefService.GetSegmentDefinitions();

    var segmentsToDeploy = allSegments.Where(seg => !segmentsFromDb.Any(dbSeg => dbSeg.Id == seg.Id));

    int processedSegments = 0;
    int skippedSegments = 0;

    foreach (var segment in segmentsToDeploy)
    {
      Item item = MasterDatabase.GetItem(Sitecore.Data.ID.Parse(segment.Id));
      if (item == null)
      {
        Response.Write(string.Format(WorkflowStateNotChangedFormat, segment.Title, segment.Id.ToString()));
        Response.Write(string.Format(NoItemFormat, segment.Title, segment.Id.ToString()));
        Response.Flush();
        skippedSegments++;

        continue;
      }

      IWorkflow workflow = MasterDatabase.WorkflowProvider.GetWorkflow(item);
      if (workflow == null)
      {
        Response.Write(string.Format(WorkflowStateNotChangedFormat, item.Name, item.ID.ToString()));
        Response.Write(string.Format(NoWorkflowFormat, item.Name, item.ID.ToString()));
        Response.Flush();
        skippedSegments++;

        continue;
      }

      Field field = item.Fields["__Workflow state"];
      if (field == null)
      {
        Response.Write(string.Format(WorkflowStateNotChangedFormat, item.Name, item.ID.ToString()));
        Response.Write(string.Format(NoWorkflowStateFormat, item.Name, item.ID.ToString()));
        Response.Flush();
        skippedSegments++;

        continue;
      }

      if (!field.Value.Equals(EAC.Globals.WorkflowStates.SegmentInitializing, StringComparison.OrdinalIgnoreCase))
      {
        item.Editing.BeginEdit();
        field.Value = EAC.Globals.WorkflowStates.SegmentInitializing;
        item.Editing.EndEdit();

        Response.Write(string.Format(WorkflowStateChangedFormat, item.Name, item.ID.ToString()));
      }
      else
      {
        Response.Write(string.Format(WorkflowStateNotChangedFormat, item.Name, item.ID.ToString()));
        Response.Write(string.Format(IncorrectWorkflowStateFormat, item.Name, item.ID.ToString()));
        Response.Flush();
        skippedSegments++;

        continue;
      }

      workflow.Execute(EAC.Globals.WorkflowCommands.DeploySegment, item, string.Empty, false);

      Response.Write(string.Format(SegmentDeployedFormat, item.Name, item.ID.ToString()));
      Response.Flush();

      processedSegments++;
    }

    Response.Write(string.Format(DeployFinished, processedSegments, skippedSegments));*/
  }

</script>