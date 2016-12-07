<%@ Page Language="C#" AutoEventWireup="true" Debug="true" %>

<%-- Common dependencies --%>
<%@ Import Namespace="System.Xml" %>
<%@ Import Namespace="System.Globalization" %>
<%-- Serialization dependency --%>
<%@ Import Namespace="Newtonsoft.Json" %>
<%-- General Sitecore dependenciese --%>
<%@ Import Namespace="Sitecore.Diagnostics" %>
<%@ Import Namespace="Sitecore.Configuration" %>
<%@ Import Namespace="Sitecore.StringExtensions" %>
<%@ Import Namespace="Sitecore.Xdb.Configuration" %>
<%-- xDB Marketing sub-system dependencies ( campaigns, goals, marketing assets, outomes definitions ) --%>
<%@ Import Namespace="Sitecore.Marketing.Definitions" %>
<%@ Import Namespace="Sitecore.Marketing.Definitions.Goals" %>
<%@ Import Namespace="Sitecore.Marketing.Definitions.Campaigns" %>
<%@ Import Namespace="Sitecore.Marketing.Definitions.Repository" %>
<%@ Import Namespace="Sitecore.Marketing.Definitions.Goals.Data" %>
<%@ Import Namespace="Sitecore.Marketing.Definitions.Outcomes.Model" %>
<%@ Import Namespace="Sitecore.Marketing.Definitions.MarketingAssets" %>
<%@ Import Namespace="Sitecore.Analytics.Reporting.DefinitionData.Marketing.Deployment" %>
<%-- xDB Marketing sub-system taxonomy sub-system dependencies (taxonomy definitions )--%>
<%@ Import Namespace="Sitecore.Marketing.Taxonomy" %>
<%@ Import Namespace="Sitecore.Marketing.Taxonomy.Data" %>
<%@ Import Namespace="Sitecore.Marketing.Taxonomy.Data.Entities" %>
<%@ Import Namespace="Sitecore.Analytics.Reporting.DefinitionData.Taxonomy" %>
<%@ Import Namespace="Sitecore.Analytics.Reporting.DefinitionData.Taxonomy.Deployment" %>
<%-- xDB Experience Analytics sub-system dependencies (segment definitions) --%>
<%@ Import Namespace="Sitecore.ExperienceAnalytics.Api" %>
<%@ Import Namespace="Sitecore.ExperienceAnalytics.Aggregation.Data.Model" %>
<%@ Import Namespace="Sitecore.ExperienceAnalytics.Core.Repositories.Model" %>

<script runat="server">
  public interface IDiagnosticProcessor
  {
    void VerifyDeployment();
  }

  public class MarketingDefinitoinsDiagnosticProcessor<T>: IDiagnosticProcessor where T : Sitecore.Marketing.Definitions.IDefinition {
    public MarketingDefinitoinsDiagnosticProcessor()
    {
      var deploymentManager = DeploymentManager.Default;
      var dFactory = DefinitionManagerFactory.Default;

      var deploymentManagerTargetRepositoryFld = deploymentManager.GetType().GetField("targetRepository", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
      var deploymentManagerTargetRepository = deploymentManagerTargetRepositoryFld.GetValue(deploymentManager) as string;
      Assert.IsNotNull(deploymentManagerTargetRepository, "deploymentManagerTargetRepository is NULL");

      this.SitecoreDefinitionManager = dFactory.GetDefinitionManager<T>();
      Assert.IsNotNull(SitecoreDefinitionManager, "MarketingDefinitoinsDiagnosticProcessor<{0}> SitecoreDefinitionManager is NULL".FormatWith(typeof(T).Name));
      this.ReportingDefinitionManager = dFactory.GetDefinitionManager<T>(deploymentManagerTargetRepository);
      Assert.IsNotNull(ReportingDefinitionManager, "MarketingDefinitoinsDiagnosticProcessor<{0}> ReportingDefinitionManager is NULL".FormatWith(typeof(T).Name));
    }

    public IDefinitionManager<T> SitecoreDefinitionManager { get; private set; }
    public IDefinitionManager<T> ReportingDefinitionManager { get; private set; }

    public void VerifyDeployment() {
      var scDefCount = SitecoreDefinitionManager.GetAll<T>(CultureInfo.InvariantCulture).Count();
      Trace.Info("MarketingDefinitoinsDiagnosticProcessor&lt;{0}&gt; fetched sitecore definitions [{1}]".FormatWith(typeof(T).Name, scDefCount));
      var rpDefCount = ReportingDefinitionManager.GetAll<T>(CultureInfo.InvariantCulture).Count();
      Trace.Info("MarketingDefinitoinsDiagnosticProcessor&lt;{0}&gt; fetched reporting definitions [{1}]".FormatWith(typeof(T).Name, rpDefCount));
    }
  }

  public class MarketingTaxonomyDiagnosticProcessor:IDiagnosticProcessor
  {
    public static class Const
    {
      public static class Taxonomy
      {
        public static readonly string RdbProviderConfigPath = "/sitecore/taxonomy/repositories/rdbTaxonomyRepository";
      }
    }

    public void VerifyDeployment()
    {
      var taxonomyDeployManager = DeployManagerProvider.GetManager();

      var scProvider = TaxonomyManager.Provider;
      var scTaxonomyManager = scProvider.GetManager(Sitecore.Marketing.Taxonomy.WellKnownIdentifiers.Items.Taxonomies.TaxonomyRootId, createIfMissing:true);
      var scTaxonomyDefinitions = scTaxonomyManager.GetAll();

      var rdbTaxonomyProvider = Sitecore.Configuration.Factory.CreateObject<RdbTaxonomyRepository>(Sitecore.Configuration.Factory.GetConfigNode(Const.Taxonomy.RdbProviderConfigPath));
      Assert.IsNotNull(rdbTaxonomyProvider, "rdbTaxonomyProvider is NULL [failed to fetch from configuration by xpath: '{0}']".FormatWith(Const.Taxonomy.RdbProviderConfigPath));
      Trace.Info("Started verification of taxonomy definitions deployment...");
      var clicker = new Clicker();
      //Groupping taxonomy definitions by taxonomy IDs. Each group will contain culture variations for the same taxonomy
      foreach ( var scTaxonomyDefinitionGroup in scTaxonomyDefinitions.GroupBy( taxonomy => taxonomy.TaxonomyId))
      {
        foreach (var scCultureSpecificTaxonomy in scTaxonomyDefinitionGroup) {
          var rdbCultureSpecificTaxonomy = rdbTaxonomyProvider.Get(scCultureSpecificTaxonomy.TaxonomyId, scCultureSpecificTaxonomy.Culture);
          VerifyTaxonomyAgainstScDefinition(scCultureSpecificTaxonomy, rdbCultureSpecificTaxonomy, clicker);
        }
      }
      Trace.Info("DONE [verification of taxonomy definitions deployment]");
      Trace.Clicker(clicker);
    }

    public void VerifyTaxonomyAgainstScDefinition(TaxonEntity scTaxonomyEntity, TaxonEntity rdbTaxonomyEntity, Clicker clicker)
    {
      clicker.Click();
      //API always returns a taxonomy entity ( even if the culture does not exist in the database ). Double-checking field language to confirm
      if (rdbTaxonomyEntity == null) {
        Trace.Err("The following taxonomy had not been deployed: '{0}:{1}'".FormatWith(scTaxonomyEntity.TaxonomyId, scTaxonomyEntity.Culture));
        clicker.Err();
        return;
      }

      if (rdbTaxonomyEntity.Fields == null || scTaxonomyEntity.Fields == null)
      {
        Trace.Warn("The taxonomy had been deployed but the culture cannot be confirmed '{0}:{1}' [This, most likely, is not a problem. Occurs only when a taxonomy does not have any fields associated with it]".FormatWith(scTaxonomyEntity.TaxonomyId, scTaxonomyEntity.Culture));
        clicker.Warn();
        return;
      }

      var rdbTaxonomyField = rdbTaxonomyEntity.Fields.First();
      var scTaxonomyField = scTaxonomyEntity.Fields.First();

      if (rdbTaxonomyField == null && scTaxonomyField == null)
      {
        Trace.Warn("The taxonomy had been deployed but the culture cannot be confirmed '{0}:{1}' [This, most likely, is not a problem. Occurs only when a taxonomy does not have any fields associated with it]".FormatWith(scTaxonomyEntity.TaxonomyId, scTaxonomyEntity.Culture));
        clicker.Warn();
        return;
      }
      else if (rdbTaxonomyField == null || scTaxonomyField == null) {
        //If only one of the fields is null - taxonomy definitions are different
        Trace.Err("Taxonomy definition mismatch for the taxonomy '{0}:{1}'".FormatWith(scTaxonomyEntity.TaxonomyId, scTaxonomyEntity.Culture));
        clicker.Err();
        return;
      }

      if (!rdbTaxonomyField.LanguageCode.Equals(scTaxonomyField.LanguageCode))
      {
        Trace.Err("Failed to confirm deployment for the following taxonomy '{0}:{1}'".FormatWith(scTaxonomyEntity.TaxonomyId, scTaxonomyEntity.Culture));
        clicker.Err();
        return;
      }
    }
  }

  public class EngagementAnalyticsDiagnosticProcessor: IDiagnosticProcessor
  {
    public static class Const
    {
      public static class ExperienceAnalytics
      {
        public static readonly string RdbAggregationSegmentReaderConfig = "/sitecore/experienceAnalytics/client/services/aggregationSegmentReader";
        public static readonly string ScSegmentReader = "/sitecore/experienceAnalytics/client/services/segmentReader";
      }
    }

    public void VerifyDeployment() {
      dynamic rdbSegmentReader = Sitecore.Configuration.Factory.CreateObject(Const.ExperienceAnalytics.RdbAggregationSegmentReaderConfig, true);
      Trace.Warn("RDB segment definitions");
      Type rdbSegmentReaderType = rdbSegmentReader.GetType();
      var rdbSegmentReaderGetAll = rdbSegmentReaderType.GetMethod("GetAll", System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Instance);
      IEnumerable<IAggregationSegment> result = rdbSegmentReaderGetAll.Invoke(rdbSegmentReader, new object[] { true });

      var rdbSegmentClicker = new Clicker();
      foreach (var entry in result) {
        Trace.Info("SegmentID: {0}; DeployDate: {1}".FormatWith(entry.SegmentId, entry.DeployDate.ToString()));
        rdbSegmentClicker.Click();
      }
      Trace.Clicker(rdbSegmentClicker);

      dynamic scSegmentReader = Sitecore.Configuration.Factory.CreateObject(Const.ExperienceAnalytics.ScSegmentReader, true);
      Trace.Warn("Sitecore segment definitions");
      Type scSegmentReaderType = scSegmentReader.GetType();
      var scSegmentReadereGetAll = scSegmentReaderType.GetMethod("GetAll", System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Instance);
      IEnumerable<SegmentDefinition> scResult = scSegmentReadereGetAll.Invoke(scSegmentReader, null);
      var scSegmentClicker = new Clicker();
      foreach (var entry in scResult)
      {
        Trace.Info("SegmentID: {0}; DeployDate: {1}; Title: {2}".FormatWith(entry.Id, entry.DeployDate.ToString(), entry.Title));
        scSegmentClicker.Click();
      }
      Trace.Clicker(scSegmentClicker);
    }
  }

  public InvocationContext UtilityInvocationContext { get; private set; }

  public void Page_Load()
  {
    this.helpContainer.Visible = false;
    if (!XdbSettings.Enabled)
    {
      Trace.Err("Sitecore xDB is disabled. Execution had been terminated");
      return;
    }

    try
    {
      this.UtilityInvocationContext = TryParseInput();
    } catch ( Exception ex )
    {
      Trace.Warn("Failed to process input parameters due to: '{0}'".FormatWith(ex.Message));
      // Display help
      this.helpContainer.Visible = true;
      return;
    }

    IDiagnosticProcessor diagnosticProcessor = null;
    try
    {
      diagnosticProcessor = TryResolveDiagnosticProcessorByCategory();
    }
    catch (Exception ex) {
      Trace.Err("Failed to resolve diagnostic processor by category due to '{0}'".FormatWith(ex.Message));
      return;
    }

    if (diagnosticProcessor == null) {
      Trace.Err("diagnosticProcessor is NULL");
      return;
    }

    switch (this.UtilityInvocationContext.Action) {
      case Action.VerifyDeployment:
        diagnosticProcessor.VerifyDeployment();
        break;
      default:
        Trace.Warn("Unsupported action");
        break;
    }
  }

  public InvocationContext TryParseInput()
  {
    var action = Action.Undefined;
    var category = DefinitionCategory.Undefined;

    var actionParam = HttpContext.Current.Request.QueryString["action"];
    if (String.IsNullOrEmpty(actionParam))
    {
      throw new Exception("'action' parameter had not been specified");
    }
    var categoryParam = HttpContext.Current.Request.QueryString["category"];
    if (String.IsNullOrEmpty(categoryParam))
    {
      throw new Exception("'category' parameter had not been specified");
    }

    switch (actionParam.ToLower()) {
      case "verify-deployment":
        action = Action.VerifyDeployment;
        break;
      default:
        throw new Exception("'action' parameter value not recognized");
    }

    switch (categoryParam.ToLower()) {
      case "m-campaigns":
        category = DefinitionCategory.MarketingCampaigns;
        break;
      case "m-goals":
        category = DefinitionCategory.MarketingGoals;
        break;
      case "m-assets":
        category = DefinitionCategory.MarketingAssets;
        break;
      case "m-outcomes":
        category = DefinitionCategory.MarketingOutcomes;
        break;
      case "m-taxonomies":
        category = DefinitionCategory.MarketingTaxonomies;
        break;
      case "ea-segments":
        category = DefinitionCategory.EngagementAnalyticSegments;
        break;
      default:
        throw new Exception("'category' parameter value not recognized");
    }

    var result = new InvocationContext(action, category);
    if (result.Action == Action.Undefined) {
      throw new Exception("'action' parameter had not been resolved");
    }
    if (result.TargetCategory == DefinitionCategory.Undefined)
    {
      throw new Exception("'category' parameter had not been resolved");
    }
    return result;
  }

  public IDiagnosticProcessor TryResolveDiagnosticProcessorByCategory()
  {
    IDiagnosticProcessor diagnosticProcessor = null;
    switch ( this.UtilityInvocationContext.TargetCategory ) {
      case DefinitionCategory.MarketingCampaigns:
        diagnosticProcessor = new MarketingDefinitoinsDiagnosticProcessor<ICampaignActivityDefinition>();
        break;
      case DefinitionCategory.MarketingGoals:
        diagnosticProcessor = new MarketingDefinitoinsDiagnosticProcessor<IGoalDefinition>();
        break;
      case DefinitionCategory.MarketingAssets:
        diagnosticProcessor = new MarketingDefinitoinsDiagnosticProcessor<IMarketingAssetDefinition>();
        break;
      case DefinitionCategory.MarketingOutcomes:
        diagnosticProcessor = new MarketingDefinitoinsDiagnosticProcessor<IOutcomeDefinition>();
        break;
      case DefinitionCategory.MarketingTaxonomies:
        diagnosticProcessor = new MarketingTaxonomyDiagnosticProcessor();
        break;
      case DefinitionCategory.EngagementAnalyticSegments:
        diagnosticProcessor = new EngagementAnalyticsDiagnosticProcessor();
        break;
      default:
        throw new Exception("Failed to resolve diagnostic processor by context category");
    }

    if (diagnosticProcessor == null) {
      throw new Exception("Resolved diagnostic processor is NULL");
    }
    return diagnosticProcessor;
  }

  public enum DefinitionCategory
  {
    MarketingCampaigns,
    MarketingGoals,
    MarketingAssets,
    MarketingOutcomes,
    MarketingTaxonomies,
    EngagementAnalyticSegments,
    Undefined
  }

  public enum Action
  {
    VerifyDeployment,
    Undefined
  }

  public class InvocationContext
  {
    public InvocationContext(Action action, DefinitionCategory targetCategory) {
      this.TargetCategory = targetCategory;
      this.Action = action;
    }

    public DefinitionCategory TargetCategory { get; private set; }
    public Action Action { get; private set; }
  }

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

</script>

<!DOCTYPE html>
<html lang="en" xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
<meta charset="utf-8" />
    <title>Sitecore xDB reporting definitions verification</title>    
</head>
<body>
  <div runat="server" id="helpContainer" visible="false">
    This is a utility page that allows to verify successfull deployment of Sitecore xDB definitions.<br />
    <b>USAGE ( via URL parameters ):</b>
    <ul>
      <li>action
        <ul>
          <li><b>verify-deployment</b></li>
        </ul>
      </li>
      <li>category
        <ul>
          <li><b>m-campaigns</b>&nbsp;<i>(Markeing campaign definitions)</i></li>
          <li><b>m-goals</b>&nbsp;<i>(Markeing goal definitions)</i></li>
          <li><b>m-assets</b>&nbsp;<i>(Markeing assets definitions)</i></li>
          <li><b>m-outcomes</b>&nbsp;<i>(Markeing outcomes definitions)</i></li>
          <li><b>m-taxonomies</b>&nbsp;<i>(Markeing taxonomies definitions)</i></li>
          <li><b>ea-segments</b>&nbsp;<i>(Engagement Analytics segments definitions)</i></li>
        </ul>
      </li>
    </ul>
  </div>
</body>
</html>
