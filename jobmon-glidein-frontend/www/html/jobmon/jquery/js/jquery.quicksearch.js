  


<!DOCTYPE html>
<html>
  <head prefix="og: http://ogp.me/ns# fb: http://ogp.me/ns/fb# githubog: http://ogp.me/ns/fb/githubog#">
    <meta charset='utf-8'>
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
        <title>quicksearch/jquery.quicksearch.js at master · riklomas/quicksearch · GitHub</title>
    <link rel="search" type="application/opensearchdescription+xml" href="/opensearch.xml" title="GitHub" />
    <link rel="fluid-icon" href="https://github.com/fluidicon.png" title="GitHub" />
    <link rel="apple-touch-icon" sizes="57x57" href="/apple-touch-icon-114.png" />
    <link rel="apple-touch-icon" sizes="114x114" href="/apple-touch-icon-114.png" />
    <link rel="apple-touch-icon" sizes="72x72" href="/apple-touch-icon-144.png" />
    <link rel="apple-touch-icon" sizes="144x144" href="/apple-touch-icon-144.png" />
    <link rel="logo" type="image/svg" href="http://github-media-downloads.s3.amazonaws.com/github-logo.svg" />
    <link rel="assets" href="https://a248.e.akamai.net/assets.github.com/">
    <link rel="xhr-socket" href="/_sockets" />
    


    <meta name="msapplication-TileImage" content="/windows-tile.png" />
    <meta name="msapplication-TileColor" content="#ffffff" />
    <meta name="selected-link" value="repo_source" data-pjax-transient />
    <meta content="collector.githubapp.com" name="octolytics-host" /><meta content="github" name="octolytics-app-id" />

    
    
    <link rel="icon" type="image/x-icon" href="/favicon.ico" />

    <meta content="authenticity_token" name="csrf-param" />
<meta content="6QywmSqhUuexDBuCJcoMYQYABKNAHtu3RPWYkZ01too=" name="csrf-token" />

    <link href="https://a248.e.akamai.net/assets.github.com/assets/github-28cb64109a7ebb60276b297a5459cd080aa82add.css" media="all" rel="stylesheet" type="text/css" />
    <link href="https://a248.e.akamai.net/assets.github.com/assets/github2-dbfecd24131ff912b4e9fe4d5a365661e862a5c5.css" media="all" rel="stylesheet" type="text/css" />
    


      <script src="https://a248.e.akamai.net/assets.github.com/assets/frameworks-4c434fa1705bf526e191eec0cd8fab1a5ce3e326.js" type="text/javascript"></script>
      <script src="https://a248.e.akamai.net/assets.github.com/assets/github-4dd8fab0e6d453f2e67265af313b0a4c78760d52.js" type="text/javascript"></script>
      
      <meta http-equiv="x-pjax-version" content="ec8147761b2439f941f2ea8a2147718c">

        <link data-pjax-transient rel='permalink' href='/riklomas/quicksearch/blob/704426a8b9070960e80b68d0fc998c88a67a94a2/jquery.quicksearch.js'>
    <meta property="og:title" content="quicksearch"/>
    <meta property="og:type" content="githubog:gitrepository"/>
    <meta property="og:url" content="https://github.com/riklomas/quicksearch"/>
    <meta property="og:image" content="https://secure.gravatar.com/avatar/5619dad363de3896cdc67719ce0cd2ac?s=420&amp;d=https://a248.e.akamai.net/assets.github.com%2Fimages%2Fgravatars%2Fgravatar-user-420.png"/>
    <meta property="og:site_name" content="GitHub"/>
    <meta property="og:description" content="quicksearch - A jQuery plugin for searching through tables, lists, etc quickly"/>
    <meta property="twitter:card" content="summary"/>
    <meta property="twitter:site" content="@GitHub">
    <meta property="twitter:title" content="riklomas/quicksearch"/>

    <meta name="description" content="quicksearch - A jQuery plugin for searching through tables, lists, etc quickly" />


    <meta content="13360" name="octolytics-dimension-user_id" /><meta content="riklomas" name="octolytics-dimension-user_login" /><meta content="46328" name="octolytics-dimension-repository_id" /><meta content="riklomas/quicksearch" name="octolytics-dimension-repository_nwo" /><meta content="true" name="octolytics-dimension-repository_public" /><meta content="false" name="octolytics-dimension-repository_is_fork" /><meta content="46328" name="octolytics-dimension-repository_network_root_id" /><meta content="riklomas/quicksearch" name="octolytics-dimension-repository_network_root_nwo" />
  <link href="https://github.com/riklomas/quicksearch/commits/master.atom" rel="alternate" title="Recent Commits to quicksearch:master" type="application/atom+xml" />

  </head>


  <body class="logged_out page-blob  vis-public env-production  ">
    <div id="wrapper">

      
      
      

      
      <div class="header header-logged-out">
  <div class="container clearfix">

    <a class="header-logo-wordmark" href="https://github.com/">Github</a>

    <div class="header-actions">
      <a class="button primary" href="/signup">Sign up</a>
      <a class="button" href="/login?return_to=%2Friklomas%2Fquicksearch%2Fblob%2Fmaster%2Fjquery.quicksearch.js">Sign in</a>
    </div>

    <div class="command-bar js-command-bar  in-repository">


      <ul class="top-nav">
          <li class="explore"><a href="/explore">Explore</a></li>
        <li class="features"><a href="/features">Features</a></li>
          <li class="enterprise"><a href="http://enterprise.github.com/">Enterprise</a></li>
          <li class="blog"><a href="/blog">Blog</a></li>
      </ul>
        <form accept-charset="UTF-8" action="/search" class="command-bar-form" id="top_search_form" method="get">
  <a href="/search/advanced" class="advanced-search-icon tooltipped downwards command-bar-search" id="advanced_search" title="Advanced search"><span class="octicon octicon-gear "></span></a>

  <input type="text" data-hotkey="/ s" name="q" id="js-command-bar-field" placeholder="Search or type a command" tabindex="1" autocapitalize="off"
    
      data-repo="riklomas/quicksearch"
      data-branch="master"
      data-sha="9de2f256dd9d476e9b1c69191d480a428e5f32df"
  >

    <input type="hidden" name="nwo" value="riklomas/quicksearch" />

    <div class="select-menu js-menu-container js-select-menu search-context-select-menu">
      <span class="minibutton select-menu-button js-menu-target">
        <span class="js-select-button">This repository</span>
      </span>

      <div class="select-menu-modal-holder js-menu-content js-navigation-container">
        <div class="select-menu-modal">

          <div class="select-menu-item js-navigation-item selected">
            <span class="select-menu-item-icon octicon octicon-check"></span>
            <input type="radio" class="js-search-this-repository" name="search_target" value="repository" checked="checked" />
            <div class="select-menu-item-text js-select-button-text">This repository</div>
          </div> <!-- /.select-menu-item -->

          <div class="select-menu-item js-navigation-item">
            <span class="select-menu-item-icon octicon octicon-check"></span>
            <input type="radio" name="search_target" value="global" />
            <div class="select-menu-item-text js-select-button-text">All repositories</div>
          </div> <!-- /.select-menu-item -->

        </div>
      </div>
    </div>

  <span class="octicon help tooltipped downwards" title="Show command bar help">
    <span class="octicon octicon-question"></span>
  </span>


  <input type="hidden" name="ref" value="cmdform">

  <div class="divider-vertical"></div>

</form>
    </div>

  </div>
</div>


      


            <div class="site hfeed" itemscope itemtype="http://schema.org/WebPage">
      <div class="hentry">
        
        <div class="pagehead repohead instapaper_ignore readability-menu ">
          <div class="container">
            <div class="title-actions-bar">
              

<ul class="pagehead-actions">



    <li>
      <a href="/login?return_to=%2Friklomas%2Fquicksearch"
        class="minibutton js-toggler-target star-button entice tooltipped upwards"
        title="You must be signed in to use this feature" rel="nofollow">
        <span class="octicon octicon-star"></span>Star
      </a>
      <a class="social-count js-social-count" href="/riklomas/quicksearch/stargazers">
        436
      </a>
    </li>
    <li>
      <a href="/login?return_to=%2Friklomas%2Fquicksearch"
        class="minibutton js-toggler-target fork-button entice tooltipped upwards"
        title="You must be signed in to fork a repository" rel="nofollow">
        <span class="octicon octicon-git-branch"></span>Fork
      </a>
      <a href="/riklomas/quicksearch/network" class="social-count">
        83
      </a>
    </li>
</ul>

              <h1 itemscope itemtype="http://data-vocabulary.org/Breadcrumb" class="entry-title public">
                <span class="repo-label"><span>public</span></span>
                <span class="mega-octicon octicon-repo"></span>
                <span class="author vcard">
                  <a href="/riklomas" class="url fn" itemprop="url" rel="author">
                  <span itemprop="title">riklomas</span>
                  </a></span> /
                <strong><a href="/riklomas/quicksearch" class="js-current-repository">quicksearch</a></strong>
              </h1>
            </div>

            
  <ul class="tabs">
    <li class="pulse-nav"><a href="/riklomas/quicksearch/pulse" class="js-selected-navigation-item " data-selected-links="pulse /riklomas/quicksearch/pulse" rel="nofollow"><span class="octicon octicon-pulse"></span></a></li>
    <li><a href="/riklomas/quicksearch" class="js-selected-navigation-item selected" data-selected-links="repo_source repo_downloads repo_commits repo_tags repo_branches /riklomas/quicksearch">Code</a></li>
    <li><a href="/riklomas/quicksearch/network" class="js-selected-navigation-item " data-selected-links="repo_network /riklomas/quicksearch/network">Network</a></li>
    <li><a href="/riklomas/quicksearch/pulls" class="js-selected-navigation-item " data-selected-links="repo_pulls /riklomas/quicksearch/pulls">Pull Requests <span class='counter'>11</span></a></li>

      <li><a href="/riklomas/quicksearch/issues" class="js-selected-navigation-item " data-selected-links="repo_issues /riklomas/quicksearch/issues">Issues <span class='counter'>48</span></a></li>



    <li><a href="/riklomas/quicksearch/graphs" class="js-selected-navigation-item " data-selected-links="repo_graphs repo_contributors /riklomas/quicksearch/graphs">Graphs</a></li>


  </ul>
  
<div class="tabnav">

  <span class="tabnav-right">
    <ul class="tabnav-tabs">
          <li><a href="/riklomas/quicksearch/tags" class="js-selected-navigation-item tabnav-tab" data-selected-links="repo_tags /riklomas/quicksearch/tags">Tags <span class="counter blank">0</span></a></li>
    </ul>
  </span>

  <div class="tabnav-widget scope">


    <div class="select-menu js-menu-container js-select-menu js-branch-menu">
      <a class="minibutton select-menu-button js-menu-target" data-hotkey="w" data-ref="master">
        <span class="octicon octicon-git-branch"></span>
        <i>branch:</i>
        <span class="js-select-button">master</span>
      </a>

      <div class="select-menu-modal-holder js-menu-content js-navigation-container">

        <div class="select-menu-modal">
          <div class="select-menu-header">
            <span class="select-menu-title">Switch branches/tags</span>
            <span class="octicon octicon-remove-close js-menu-close"></span>
          </div> <!-- /.select-menu-header -->

          <div class="select-menu-filters">
            <div class="select-menu-text-filter">
              <input type="text" id="commitish-filter-field" class="js-filterable-field js-navigation-enable" placeholder="Filter branches/tags">
            </div>
            <div class="select-menu-tabs">
              <ul>
                <li class="select-menu-tab">
                  <a href="#" data-tab-filter="branches" class="js-select-menu-tab">Branches</a>
                </li>
                <li class="select-menu-tab">
                  <a href="#" data-tab-filter="tags" class="js-select-menu-tab">Tags</a>
                </li>
              </ul>
            </div><!-- /.select-menu-tabs -->
          </div><!-- /.select-menu-filters -->

          <div class="select-menu-list select-menu-tab-bucket js-select-menu-tab-bucket css-truncate" data-tab-filter="branches">

            <div data-filterable-for="commitish-filter-field" data-filterable-type="substring">

                <div class="select-menu-item js-navigation-item ">
                  <span class="select-menu-item-icon octicon octicon-check"></span>
                  <a href="/riklomas/quicksearch/blob/dev/jquery.quicksearch.js" class="js-navigation-open select-menu-item-text js-select-button-text css-truncate-target" data-name="dev" rel="nofollow" title="dev">dev</a>
                </div> <!-- /.select-menu-item -->
                <div class="select-menu-item js-navigation-item selected">
                  <span class="select-menu-item-icon octicon octicon-check"></span>
                  <a href="/riklomas/quicksearch/blob/master/jquery.quicksearch.js" class="js-navigation-open select-menu-item-text js-select-button-text css-truncate-target" data-name="master" rel="nofollow" title="master">master</a>
                </div> <!-- /.select-menu-item -->
            </div>

              <div class="select-menu-no-results">Nothing to show</div>
          </div> <!-- /.select-menu-list -->


          <div class="select-menu-list select-menu-tab-bucket js-select-menu-tab-bucket css-truncate" data-tab-filter="tags">
            <div data-filterable-for="commitish-filter-field" data-filterable-type="substring">

            </div>

            <div class="select-menu-no-results">Nothing to show</div>

          </div> <!-- /.select-menu-list -->

        </div> <!-- /.select-menu-modal -->
      </div> <!-- /.select-menu-modal-holder -->
    </div> <!-- /.select-menu -->

  </div> <!-- /.scope -->

  <ul class="tabnav-tabs">
    <li><a href="/riklomas/quicksearch" class="selected js-selected-navigation-item tabnav-tab" data-selected-links="repo_source /riklomas/quicksearch">Files</a></li>
    <li><a href="/riklomas/quicksearch/commits/master" class="js-selected-navigation-item tabnav-tab" data-selected-links="repo_commits /riklomas/quicksearch/commits/master">Commits</a></li>
    <li><a href="/riklomas/quicksearch/branches" class="js-selected-navigation-item tabnav-tab" data-selected-links="repo_branches /riklomas/quicksearch/branches" rel="nofollow">Branches <span class="counter ">2</span></a></li>
  </ul>

</div>

  
  
  


            
          </div>
        </div><!-- /.repohead -->

        <div id="js-repo-pjax-container" class="container context-loader-container" data-pjax-container>
          


<!-- blob contrib key: blob_contributors:v21:ec2b5562cd48a977e231d43ce5a42604 -->
<!-- blob contrib frag key: views10/v8/blob_contributors:v21:ec2b5562cd48a977e231d43ce5a42604 -->


<div id="slider">
    <div class="frame-meta">

      <p title="This is a placeholder element" class="js-history-link-replace hidden"></p>

        <div class="breadcrumb">
          <span class='bold'><span itemscope="" itemtype="http://data-vocabulary.org/Breadcrumb"><a href="/riklomas/quicksearch" class="js-slide-to" data-branch="master" data-direction="back" itemscope="url"><span itemprop="title">quicksearch</span></a></span></span><span class="separator"> / </span><strong class="final-path">jquery.quicksearch.js</strong> <span class="js-zeroclipboard zeroclipboard-button" data-clipboard-text="jquery.quicksearch.js" data-copied-hint="copied!" title="copy to clipboard"><span class="octicon octicon-clippy"></span></span>
        </div>

      <a href="/riklomas/quicksearch/find/master" class="js-slide-to" data-hotkey="t" style="display:none">Show File Finder</a>


        
  <div class="commit file-history-tease">
    <img class="main-avatar" height="24" src="https://secure.gravatar.com/avatar/3d9946f27d54498c13b7ce7b000dca73?s=140&amp;d=https://a248.e.akamai.net/assets.github.com%2Fimages%2Fgravatars%2Fgravatar-user-420.png" width="24" />
    <span class="author"><a href="/tankchintan" rel="author">tankchintan</a></span>
    <time class="js-relative-date" datetime="2012-01-18T09:11:00-08:00" title="2012-01-18 09:11:00">January 18, 2012</time>
    <div class="commit-title">
        <a href="/riklomas/quicksearch/commit/3ad9c10a6b1571d97ca2e055a7f754507526cd70" class="message">Added APIs for initiating search programatically, count of matched re…</a>
    </div>

    <div class="participation">
      <p class="quickstat"><a href="#blob_contributors_box" rel="facebox"><strong>3</strong> contributors</a></p>
          <a class="avatar tooltipped downwards" title="riklomas" href="/riklomas/quicksearch/commits/master/jquery.quicksearch.js?author=riklomas"><img height="20" src="https://secure.gravatar.com/avatar/5619dad363de3896cdc67719ce0cd2ac?s=140&amp;d=https://a248.e.akamai.net/assets.github.com%2Fimages%2Fgravatars%2Fgravatar-user-420.png" width="20" /></a>
    <a class="avatar tooltipped downwards" title="tankchintan" href="/riklomas/quicksearch/commits/master/jquery.quicksearch.js?author=tankchintan"><img height="20" src="https://secure.gravatar.com/avatar/3d9946f27d54498c13b7ce7b000dca73?s=140&amp;d=https://a248.e.akamai.net/assets.github.com%2Fimages%2Fgravatars%2Fgravatar-user-420.png" width="20" /></a>
    <a class="avatar tooltipped downwards" title="goj" href="/riklomas/quicksearch/commits/master/jquery.quicksearch.js?author=goj"><img height="20" src="https://secure.gravatar.com/avatar/f0e203b46d2cb2b4d59c823dab6302dd?s=140&amp;d=https://a248.e.akamai.net/assets.github.com%2Fimages%2Fgravatars%2Fgravatar-user-420.png" width="20" /></a>


    </div>
    <div id="blob_contributors_box" style="display:none">
      <h2>Users on GitHub who have contributed to this file</h2>
      <ul class="facebox-user-list">
        <li>
          <img height="24" src="https://secure.gravatar.com/avatar/5619dad363de3896cdc67719ce0cd2ac?s=140&amp;d=https://a248.e.akamai.net/assets.github.com%2Fimages%2Fgravatars%2Fgravatar-user-420.png" width="24" />
          <a href="/riklomas">riklomas</a>
        </li>
        <li>
          <img height="24" src="https://secure.gravatar.com/avatar/3d9946f27d54498c13b7ce7b000dca73?s=140&amp;d=https://a248.e.akamai.net/assets.github.com%2Fimages%2Fgravatars%2Fgravatar-user-420.png" width="24" />
          <a href="/tankchintan">tankchintan</a>
        </li>
        <li>
          <img height="24" src="https://secure.gravatar.com/avatar/f0e203b46d2cb2b4d59c823dab6302dd?s=140&amp;d=https://a248.e.akamai.net/assets.github.com%2Fimages%2Fgravatars%2Fgravatar-user-420.png" width="24" />
          <a href="/goj">goj</a>
        </li>
      </ul>
    </div>
  </div>


    </div><!-- ./.frame-meta -->

    <div class="frames">
      <div class="frame" data-permalink-url="/riklomas/quicksearch/blob/704426a8b9070960e80b68d0fc998c88a67a94a2/jquery.quicksearch.js" data-title="quicksearch/jquery.quicksearch.js at master · riklomas/quicksearch · GitHub" data-type="blob">

        <div id="files" class="bubble">
          <div class="file">
            <div class="meta">
              <div class="info">
                <span class="icon"><b class="octicon octicon-file-text"></b></span>
                <span class="mode" title="File Mode">file</span>
                  <span>182 lines (149 sloc)</span>
                <span>4.179 kb</span>
              </div>
              <div class="actions">
                <div class="button-group">
                      <a class="minibutton js-entice" href=""
                         data-entice="You must be signed in and on a branch to make or propose changes">Edit</a>
                  <a href="/riklomas/quicksearch/raw/master/jquery.quicksearch.js" class="button minibutton " id="raw-url">Raw</a>
                    <a href="/riklomas/quicksearch/blame/master/jquery.quicksearch.js" class="button minibutton ">Blame</a>
                  <a href="/riklomas/quicksearch/commits/master/jquery.quicksearch.js" class="button minibutton " rel="nofollow">History</a>
                </div><!-- /.button-group -->
              </div><!-- /.actions -->

            </div>
                <div class="blob-wrapper data type-javascript js-blob-data">
      <table class="file-code file-diff">
        <tr class="file-code-line">
          <td class="blob-line-nums">
            <span id="L1" rel="#L1">1</span>
<span id="L2" rel="#L2">2</span>
<span id="L3" rel="#L3">3</span>
<span id="L4" rel="#L4">4</span>
<span id="L5" rel="#L5">5</span>
<span id="L6" rel="#L6">6</span>
<span id="L7" rel="#L7">7</span>
<span id="L8" rel="#L8">8</span>
<span id="L9" rel="#L9">9</span>
<span id="L10" rel="#L10">10</span>
<span id="L11" rel="#L11">11</span>
<span id="L12" rel="#L12">12</span>
<span id="L13" rel="#L13">13</span>
<span id="L14" rel="#L14">14</span>
<span id="L15" rel="#L15">15</span>
<span id="L16" rel="#L16">16</span>
<span id="L17" rel="#L17">17</span>
<span id="L18" rel="#L18">18</span>
<span id="L19" rel="#L19">19</span>
<span id="L20" rel="#L20">20</span>
<span id="L21" rel="#L21">21</span>
<span id="L22" rel="#L22">22</span>
<span id="L23" rel="#L23">23</span>
<span id="L24" rel="#L24">24</span>
<span id="L25" rel="#L25">25</span>
<span id="L26" rel="#L26">26</span>
<span id="L27" rel="#L27">27</span>
<span id="L28" rel="#L28">28</span>
<span id="L29" rel="#L29">29</span>
<span id="L30" rel="#L30">30</span>
<span id="L31" rel="#L31">31</span>
<span id="L32" rel="#L32">32</span>
<span id="L33" rel="#L33">33</span>
<span id="L34" rel="#L34">34</span>
<span id="L35" rel="#L35">35</span>
<span id="L36" rel="#L36">36</span>
<span id="L37" rel="#L37">37</span>
<span id="L38" rel="#L38">38</span>
<span id="L39" rel="#L39">39</span>
<span id="L40" rel="#L40">40</span>
<span id="L41" rel="#L41">41</span>
<span id="L42" rel="#L42">42</span>
<span id="L43" rel="#L43">43</span>
<span id="L44" rel="#L44">44</span>
<span id="L45" rel="#L45">45</span>
<span id="L46" rel="#L46">46</span>
<span id="L47" rel="#L47">47</span>
<span id="L48" rel="#L48">48</span>
<span id="L49" rel="#L49">49</span>
<span id="L50" rel="#L50">50</span>
<span id="L51" rel="#L51">51</span>
<span id="L52" rel="#L52">52</span>
<span id="L53" rel="#L53">53</span>
<span id="L54" rel="#L54">54</span>
<span id="L55" rel="#L55">55</span>
<span id="L56" rel="#L56">56</span>
<span id="L57" rel="#L57">57</span>
<span id="L58" rel="#L58">58</span>
<span id="L59" rel="#L59">59</span>
<span id="L60" rel="#L60">60</span>
<span id="L61" rel="#L61">61</span>
<span id="L62" rel="#L62">62</span>
<span id="L63" rel="#L63">63</span>
<span id="L64" rel="#L64">64</span>
<span id="L65" rel="#L65">65</span>
<span id="L66" rel="#L66">66</span>
<span id="L67" rel="#L67">67</span>
<span id="L68" rel="#L68">68</span>
<span id="L69" rel="#L69">69</span>
<span id="L70" rel="#L70">70</span>
<span id="L71" rel="#L71">71</span>
<span id="L72" rel="#L72">72</span>
<span id="L73" rel="#L73">73</span>
<span id="L74" rel="#L74">74</span>
<span id="L75" rel="#L75">75</span>
<span id="L76" rel="#L76">76</span>
<span id="L77" rel="#L77">77</span>
<span id="L78" rel="#L78">78</span>
<span id="L79" rel="#L79">79</span>
<span id="L80" rel="#L80">80</span>
<span id="L81" rel="#L81">81</span>
<span id="L82" rel="#L82">82</span>
<span id="L83" rel="#L83">83</span>
<span id="L84" rel="#L84">84</span>
<span id="L85" rel="#L85">85</span>
<span id="L86" rel="#L86">86</span>
<span id="L87" rel="#L87">87</span>
<span id="L88" rel="#L88">88</span>
<span id="L89" rel="#L89">89</span>
<span id="L90" rel="#L90">90</span>
<span id="L91" rel="#L91">91</span>
<span id="L92" rel="#L92">92</span>
<span id="L93" rel="#L93">93</span>
<span id="L94" rel="#L94">94</span>
<span id="L95" rel="#L95">95</span>
<span id="L96" rel="#L96">96</span>
<span id="L97" rel="#L97">97</span>
<span id="L98" rel="#L98">98</span>
<span id="L99" rel="#L99">99</span>
<span id="L100" rel="#L100">100</span>
<span id="L101" rel="#L101">101</span>
<span id="L102" rel="#L102">102</span>
<span id="L103" rel="#L103">103</span>
<span id="L104" rel="#L104">104</span>
<span id="L105" rel="#L105">105</span>
<span id="L106" rel="#L106">106</span>
<span id="L107" rel="#L107">107</span>
<span id="L108" rel="#L108">108</span>
<span id="L109" rel="#L109">109</span>
<span id="L110" rel="#L110">110</span>
<span id="L111" rel="#L111">111</span>
<span id="L112" rel="#L112">112</span>
<span id="L113" rel="#L113">113</span>
<span id="L114" rel="#L114">114</span>
<span id="L115" rel="#L115">115</span>
<span id="L116" rel="#L116">116</span>
<span id="L117" rel="#L117">117</span>
<span id="L118" rel="#L118">118</span>
<span id="L119" rel="#L119">119</span>
<span id="L120" rel="#L120">120</span>
<span id="L121" rel="#L121">121</span>
<span id="L122" rel="#L122">122</span>
<span id="L123" rel="#L123">123</span>
<span id="L124" rel="#L124">124</span>
<span id="L125" rel="#L125">125</span>
<span id="L126" rel="#L126">126</span>
<span id="L127" rel="#L127">127</span>
<span id="L128" rel="#L128">128</span>
<span id="L129" rel="#L129">129</span>
<span id="L130" rel="#L130">130</span>
<span id="L131" rel="#L131">131</span>
<span id="L132" rel="#L132">132</span>
<span id="L133" rel="#L133">133</span>
<span id="L134" rel="#L134">134</span>
<span id="L135" rel="#L135">135</span>
<span id="L136" rel="#L136">136</span>
<span id="L137" rel="#L137">137</span>
<span id="L138" rel="#L138">138</span>
<span id="L139" rel="#L139">139</span>
<span id="L140" rel="#L140">140</span>
<span id="L141" rel="#L141">141</span>
<span id="L142" rel="#L142">142</span>
<span id="L143" rel="#L143">143</span>
<span id="L144" rel="#L144">144</span>
<span id="L145" rel="#L145">145</span>
<span id="L146" rel="#L146">146</span>
<span id="L147" rel="#L147">147</span>
<span id="L148" rel="#L148">148</span>
<span id="L149" rel="#L149">149</span>
<span id="L150" rel="#L150">150</span>
<span id="L151" rel="#L151">151</span>
<span id="L152" rel="#L152">152</span>
<span id="L153" rel="#L153">153</span>
<span id="L154" rel="#L154">154</span>
<span id="L155" rel="#L155">155</span>
<span id="L156" rel="#L156">156</span>
<span id="L157" rel="#L157">157</span>
<span id="L158" rel="#L158">158</span>
<span id="L159" rel="#L159">159</span>
<span id="L160" rel="#L160">160</span>
<span id="L161" rel="#L161">161</span>
<span id="L162" rel="#L162">162</span>
<span id="L163" rel="#L163">163</span>
<span id="L164" rel="#L164">164</span>
<span id="L165" rel="#L165">165</span>
<span id="L166" rel="#L166">166</span>
<span id="L167" rel="#L167">167</span>
<span id="L168" rel="#L168">168</span>
<span id="L169" rel="#L169">169</span>
<span id="L170" rel="#L170">170</span>
<span id="L171" rel="#L171">171</span>
<span id="L172" rel="#L172">172</span>
<span id="L173" rel="#L173">173</span>
<span id="L174" rel="#L174">174</span>
<span id="L175" rel="#L175">175</span>
<span id="L176" rel="#L176">176</span>
<span id="L177" rel="#L177">177</span>
<span id="L178" rel="#L178">178</span>
<span id="L179" rel="#L179">179</span>
<span id="L180" rel="#L180">180</span>
<span id="L181" rel="#L181">181</span>

          </td>
          <td class="blob-line-code">
                  <div class="highlight"><pre><div class='line' id='LC1'><span class="p">(</span><span class="kd">function</span><span class="p">(</span><span class="nx">$</span><span class="p">,</span> <span class="nb">window</span><span class="p">,</span> <span class="nb">document</span><span class="p">,</span> <span class="kc">undefined</span><span class="p">)</span> <span class="p">{</span></div><div class='line' id='LC2'>	<span class="nx">$</span><span class="p">.</span><span class="nx">fn</span><span class="p">.</span><span class="nx">quicksearch</span> <span class="o">=</span> <span class="kd">function</span> <span class="p">(</span><span class="nx">target</span><span class="p">,</span> <span class="nx">opt</span><span class="p">)</span> <span class="p">{</span></div><div class='line' id='LC3'><br/></div><div class='line' id='LC4'>		<span class="kd">var</span> <span class="nx">timeout</span><span class="p">,</span> <span class="nx">cache</span><span class="p">,</span> <span class="nx">rowcache</span><span class="p">,</span> <span class="nx">jq_results</span><span class="p">,</span> <span class="nx">val</span> <span class="o">=</span> <span class="s1">&#39;&#39;</span><span class="p">,</span> <span class="nx">e</span> <span class="o">=</span> <span class="k">this</span><span class="p">,</span> <span class="nx">options</span> <span class="o">=</span> <span class="nx">$</span><span class="p">.</span><span class="nx">extend</span><span class="p">({</span> </div><div class='line' id='LC5'>			<span class="nx">delay</span><span class="o">:</span> <span class="mi">100</span><span class="p">,</span></div><div class='line' id='LC6'>			<span class="nx">selector</span><span class="o">:</span> <span class="kc">null</span><span class="p">,</span></div><div class='line' id='LC7'>			<span class="nx">stripeRows</span><span class="o">:</span> <span class="kc">null</span><span class="p">,</span></div><div class='line' id='LC8'>			<span class="nx">loader</span><span class="o">:</span> <span class="kc">null</span><span class="p">,</span></div><div class='line' id='LC9'>			<span class="nx">noResults</span><span class="o">:</span> <span class="s1">&#39;&#39;</span><span class="p">,</span></div><div class='line' id='LC10'>			<span class="nx">matchedResultsCount</span><span class="o">:</span> <span class="mi">0</span><span class="p">,</span></div><div class='line' id='LC11'>			<span class="nx">bind</span><span class="o">:</span> <span class="s1">&#39;keyup&#39;</span><span class="p">,</span></div><div class='line' id='LC12'>			<span class="nx">onBefore</span><span class="o">:</span> <span class="kd">function</span> <span class="p">()</span> <span class="p">{</span> </div><div class='line' id='LC13'>				<span class="k">return</span><span class="p">;</span></div><div class='line' id='LC14'>			<span class="p">},</span></div><div class='line' id='LC15'>			<span class="nx">onAfter</span><span class="o">:</span> <span class="kd">function</span> <span class="p">()</span> <span class="p">{</span> </div><div class='line' id='LC16'>				<span class="k">return</span><span class="p">;</span></div><div class='line' id='LC17'>			<span class="p">},</span></div><div class='line' id='LC18'>			<span class="nx">show</span><span class="o">:</span> <span class="kd">function</span> <span class="p">()</span> <span class="p">{</span></div><div class='line' id='LC19'>				<span class="k">this</span><span class="p">.</span><span class="nx">style</span><span class="p">.</span><span class="nx">display</span> <span class="o">=</span> <span class="s2">&quot;&quot;</span><span class="p">;</span></div><div class='line' id='LC20'>			<span class="p">},</span></div><div class='line' id='LC21'>			<span class="nx">hide</span><span class="o">:</span> <span class="kd">function</span> <span class="p">()</span> <span class="p">{</span></div><div class='line' id='LC22'>				<span class="k">this</span><span class="p">.</span><span class="nx">style</span><span class="p">.</span><span class="nx">display</span> <span class="o">=</span> <span class="s2">&quot;none&quot;</span><span class="p">;</span></div><div class='line' id='LC23'>			<span class="p">},</span></div><div class='line' id='LC24'>			<span class="nx">prepareQuery</span><span class="o">:</span> <span class="kd">function</span> <span class="p">(</span><span class="nx">val</span><span class="p">)</span> <span class="p">{</span></div><div class='line' id='LC25'>				<span class="k">return</span> <span class="nx">val</span><span class="p">.</span><span class="nx">toLowerCase</span><span class="p">().</span><span class="nx">split</span><span class="p">(</span><span class="s1">&#39; &#39;</span><span class="p">);</span></div><div class='line' id='LC26'>			<span class="p">},</span></div><div class='line' id='LC27'>			<span class="nx">testQuery</span><span class="o">:</span> <span class="kd">function</span> <span class="p">(</span><span class="nx">query</span><span class="p">,</span> <span class="nx">txt</span><span class="p">,</span> <span class="nx">_row</span><span class="p">)</span> <span class="p">{</span></div><div class='line' id='LC28'>				<span class="k">for</span> <span class="p">(</span><span class="kd">var</span> <span class="nx">i</span> <span class="o">=</span> <span class="mi">0</span><span class="p">;</span> <span class="nx">i</span> <span class="o">&lt;</span> <span class="nx">query</span><span class="p">.</span><span class="nx">length</span><span class="p">;</span> <span class="nx">i</span> <span class="o">+=</span> <span class="mi">1</span><span class="p">)</span> <span class="p">{</span></div><div class='line' id='LC29'>					<span class="k">if</span> <span class="p">(</span><span class="nx">txt</span><span class="p">.</span><span class="nx">indexOf</span><span class="p">(</span><span class="nx">query</span><span class="p">[</span><span class="nx">i</span><span class="p">])</span> <span class="o">===</span> <span class="o">-</span><span class="mi">1</span><span class="p">)</span> <span class="p">{</span></div><div class='line' id='LC30'>						<span class="k">return</span> <span class="kc">false</span><span class="p">;</span></div><div class='line' id='LC31'>					<span class="p">}</span></div><div class='line' id='LC32'>				<span class="p">}</span></div><div class='line' id='LC33'>				<span class="k">return</span> <span class="kc">true</span><span class="p">;</span></div><div class='line' id='LC34'>			<span class="p">}</span></div><div class='line' id='LC35'>		<span class="p">},</span> <span class="nx">opt</span><span class="p">);</span></div><div class='line' id='LC36'><br/></div><div class='line' id='LC37'>		<span class="k">this</span><span class="p">.</span><span class="nx">go</span> <span class="o">=</span> <span class="kd">function</span> <span class="p">()</span> <span class="p">{</span></div><div class='line' id='LC38'><br/></div><div class='line' id='LC39'>			<span class="kd">var</span> <span class="nx">i</span> <span class="o">=</span> <span class="mi">0</span><span class="p">,</span></div><div class='line' id='LC40'>				<span class="nx">numMatchedRows</span> <span class="o">=</span> <span class="mi">0</span><span class="p">,</span></div><div class='line' id='LC41'>				<span class="nx">noresults</span> <span class="o">=</span> <span class="kc">true</span><span class="p">,</span> </div><div class='line' id='LC42'>				<span class="nx">query</span> <span class="o">=</span> <span class="nx">options</span><span class="p">.</span><span class="nx">prepareQuery</span><span class="p">(</span><span class="nx">val</span><span class="p">),</span></div><div class='line' id='LC43'>				<span class="nx">val_empty</span> <span class="o">=</span> <span class="p">(</span><span class="nx">val</span><span class="p">.</span><span class="nx">replace</span><span class="p">(</span><span class="s1">&#39; &#39;</span><span class="p">,</span> <span class="s1">&#39;&#39;</span><span class="p">).</span><span class="nx">length</span> <span class="o">===</span> <span class="mi">0</span><span class="p">);</span></div><div class='line' id='LC44'><br/></div><div class='line' id='LC45'>			<span class="k">for</span> <span class="p">(</span><span class="kd">var</span> <span class="nx">i</span> <span class="o">=</span> <span class="mi">0</span><span class="p">,</span> <span class="nx">len</span> <span class="o">=</span> <span class="nx">rowcache</span><span class="p">.</span><span class="nx">length</span><span class="p">;</span> <span class="nx">i</span> <span class="o">&lt;</span> <span class="nx">len</span><span class="p">;</span> <span class="nx">i</span><span class="o">++</span><span class="p">)</span> <span class="p">{</span></div><div class='line' id='LC46'>				<span class="k">if</span> <span class="p">(</span><span class="nx">val_empty</span> <span class="o">||</span> <span class="nx">options</span><span class="p">.</span><span class="nx">testQuery</span><span class="p">(</span><span class="nx">query</span><span class="p">,</span> <span class="nx">cache</span><span class="p">[</span><span class="nx">i</span><span class="p">],</span> <span class="nx">rowcache</span><span class="p">[</span><span class="nx">i</span><span class="p">]))</span> <span class="p">{</span></div><div class='line' id='LC47'>					<span class="nx">options</span><span class="p">.</span><span class="nx">show</span><span class="p">.</span><span class="nx">apply</span><span class="p">(</span><span class="nx">rowcache</span><span class="p">[</span><span class="nx">i</span><span class="p">]);</span></div><div class='line' id='LC48'>					<span class="nx">noresults</span> <span class="o">=</span> <span class="kc">false</span><span class="p">;</span></div><div class='line' id='LC49'>					<span class="nx">numMatchedRows</span><span class="o">++</span><span class="p">;</span></div><div class='line' id='LC50'>				<span class="p">}</span> <span class="k">else</span> <span class="p">{</span></div><div class='line' id='LC51'>					<span class="nx">options</span><span class="p">.</span><span class="nx">hide</span><span class="p">.</span><span class="nx">apply</span><span class="p">(</span><span class="nx">rowcache</span><span class="p">[</span><span class="nx">i</span><span class="p">]);</span></div><div class='line' id='LC52'>				<span class="p">}</span></div><div class='line' id='LC53'>			<span class="p">}</span></div><div class='line' id='LC54'><br/></div><div class='line' id='LC55'>			<span class="k">if</span> <span class="p">(</span><span class="nx">noresults</span><span class="p">)</span> <span class="p">{</span></div><div class='line' id='LC56'>				<span class="k">this</span><span class="p">.</span><span class="nx">results</span><span class="p">(</span><span class="kc">false</span><span class="p">);</span></div><div class='line' id='LC57'>			<span class="p">}</span> <span class="k">else</span> <span class="p">{</span></div><div class='line' id='LC58'>				<span class="k">this</span><span class="p">.</span><span class="nx">results</span><span class="p">(</span><span class="kc">true</span><span class="p">);</span></div><div class='line' id='LC59'>				<span class="k">this</span><span class="p">.</span><span class="nx">stripe</span><span class="p">();</span></div><div class='line' id='LC60'>			<span class="p">}</span></div><div class='line' id='LC61'><br/></div><div class='line' id='LC62'>			<span class="k">this</span><span class="p">.</span><span class="nx">matchedResultsCount</span> <span class="o">=</span> <span class="nx">numMatchedRows</span><span class="p">;</span></div><div class='line' id='LC63'>			<span class="k">this</span><span class="p">.</span><span class="nx">loader</span><span class="p">(</span><span class="kc">false</span><span class="p">);</span></div><div class='line' id='LC64'>			<span class="nx">options</span><span class="p">.</span><span class="nx">onAfter</span><span class="p">();</span></div><div class='line' id='LC65'><br/></div><div class='line' id='LC66'>			<span class="k">return</span> <span class="k">this</span><span class="p">;</span></div><div class='line' id='LC67'>		<span class="p">};</span></div><div class='line' id='LC68'><br/></div><div class='line' id='LC69'>		<span class="cm">/*</span></div><div class='line' id='LC70'><span class="cm">		 * External API so that users can perform search programatically. </span></div><div class='line' id='LC71'><span class="cm">		 * */</span></div><div class='line' id='LC72'>		<span class="k">this</span><span class="p">.</span><span class="nx">search</span> <span class="o">=</span> <span class="kd">function</span> <span class="p">(</span><span class="nx">submittedVal</span><span class="p">)</span> <span class="p">{</span></div><div class='line' id='LC73'>			<span class="nx">val</span> <span class="o">=</span> <span class="nx">submittedVal</span><span class="p">;</span></div><div class='line' id='LC74'>			<span class="nx">e</span><span class="p">.</span><span class="nx">trigger</span><span class="p">();</span></div><div class='line' id='LC75'>		<span class="p">};</span></div><div class='line' id='LC76'><br/></div><div class='line' id='LC77'>		<span class="cm">/*</span></div><div class='line' id='LC78'><span class="cm">		 * External API to get the number of matched results as seen in </span></div><div class='line' id='LC79'><span class="cm">		 * https://github.com/ruiz107/quicksearch/commit/f78dc440b42d95ce9caed1d087174dd4359982d6</span></div><div class='line' id='LC80'><span class="cm">		 * */</span></div><div class='line' id='LC81'>		<span class="k">this</span><span class="p">.</span><span class="nx">currentMatchedResults</span> <span class="o">=</span> <span class="kd">function</span><span class="p">()</span> <span class="p">{</span></div><div class='line' id='LC82'>			<span class="k">return</span> <span class="k">this</span><span class="p">.</span><span class="nx">matchedResultsCount</span><span class="p">;</span></div><div class='line' id='LC83'>		<span class="p">};</span></div><div class='line' id='LC84'><br/></div><div class='line' id='LC85'>		<span class="k">this</span><span class="p">.</span><span class="nx">stripe</span> <span class="o">=</span> <span class="kd">function</span> <span class="p">()</span> <span class="p">{</span></div><div class='line' id='LC86'><br/></div><div class='line' id='LC87'>			<span class="k">if</span> <span class="p">(</span><span class="k">typeof</span> <span class="nx">options</span><span class="p">.</span><span class="nx">stripeRows</span> <span class="o">===</span> <span class="s2">&quot;object&quot;</span> <span class="o">&amp;&amp;</span> <span class="nx">options</span><span class="p">.</span><span class="nx">stripeRows</span> <span class="o">!==</span> <span class="kc">null</span><span class="p">)</span></div><div class='line' id='LC88'>			<span class="p">{</span></div><div class='line' id='LC89'>				<span class="kd">var</span> <span class="nx">joined</span> <span class="o">=</span> <span class="nx">options</span><span class="p">.</span><span class="nx">stripeRows</span><span class="p">.</span><span class="nx">join</span><span class="p">(</span><span class="s1">&#39; &#39;</span><span class="p">);</span></div><div class='line' id='LC90'>				<span class="kd">var</span> <span class="nx">stripeRows_length</span> <span class="o">=</span> <span class="nx">options</span><span class="p">.</span><span class="nx">stripeRows</span><span class="p">.</span><span class="nx">length</span><span class="p">;</span></div><div class='line' id='LC91'><br/></div><div class='line' id='LC92'>				<span class="nx">jq_results</span><span class="p">.</span><span class="nx">not</span><span class="p">(</span><span class="s1">&#39;:hidden&#39;</span><span class="p">).</span><span class="nx">each</span><span class="p">(</span><span class="kd">function</span> <span class="p">(</span><span class="nx">i</span><span class="p">)</span> <span class="p">{</span></div><div class='line' id='LC93'>					<span class="nx">$</span><span class="p">(</span><span class="k">this</span><span class="p">).</span><span class="nx">removeClass</span><span class="p">(</span><span class="nx">joined</span><span class="p">).</span><span class="nx">addClass</span><span class="p">(</span><span class="nx">options</span><span class="p">.</span><span class="nx">stripeRows</span><span class="p">[</span><span class="nx">i</span> <span class="o">%</span> <span class="nx">stripeRows_length</span><span class="p">]);</span></div><div class='line' id='LC94'>				<span class="p">});</span></div><div class='line' id='LC95'>			<span class="p">}</span></div><div class='line' id='LC96'><br/></div><div class='line' id='LC97'>			<span class="k">return</span> <span class="k">this</span><span class="p">;</span></div><div class='line' id='LC98'>		<span class="p">};</span></div><div class='line' id='LC99'><br/></div><div class='line' id='LC100'>		<span class="k">this</span><span class="p">.</span><span class="nx">strip_html</span> <span class="o">=</span> <span class="kd">function</span> <span class="p">(</span><span class="nx">input</span><span class="p">)</span> <span class="p">{</span></div><div class='line' id='LC101'>			<span class="kd">var</span> <span class="nx">output</span> <span class="o">=</span> <span class="nx">input</span><span class="p">.</span><span class="nx">replace</span><span class="p">(</span><span class="k">new</span> <span class="nb">RegExp</span><span class="p">(</span><span class="s1">&#39;&lt;[^&lt;]+\&gt;&#39;</span><span class="p">,</span> <span class="s1">&#39;g&#39;</span><span class="p">),</span> <span class="s2">&quot;&quot;</span><span class="p">);</span></div><div class='line' id='LC102'>			<span class="nx">output</span> <span class="o">=</span> <span class="nx">$</span><span class="p">.</span><span class="nx">trim</span><span class="p">(</span><span class="nx">output</span><span class="p">.</span><span class="nx">toLowerCase</span><span class="p">());</span></div><div class='line' id='LC103'>			<span class="k">return</span> <span class="nx">output</span><span class="p">;</span></div><div class='line' id='LC104'>		<span class="p">};</span></div><div class='line' id='LC105'><br/></div><div class='line' id='LC106'>		<span class="k">this</span><span class="p">.</span><span class="nx">results</span> <span class="o">=</span> <span class="kd">function</span> <span class="p">(</span><span class="nx">bool</span><span class="p">)</span> <span class="p">{</span></div><div class='line' id='LC107'>			<span class="k">if</span> <span class="p">(</span><span class="k">typeof</span> <span class="nx">options</span><span class="p">.</span><span class="nx">noResults</span> <span class="o">===</span> <span class="s2">&quot;string&quot;</span> <span class="o">&amp;&amp;</span> <span class="nx">options</span><span class="p">.</span><span class="nx">noResults</span> <span class="o">!==</span> <span class="s2">&quot;&quot;</span><span class="p">)</span> <span class="p">{</span></div><div class='line' id='LC108'>				<span class="k">if</span> <span class="p">(</span><span class="nx">bool</span><span class="p">)</span> <span class="p">{</span></div><div class='line' id='LC109'>					<span class="nx">$</span><span class="p">(</span><span class="nx">options</span><span class="p">.</span><span class="nx">noResults</span><span class="p">).</span><span class="nx">hide</span><span class="p">();</span></div><div class='line' id='LC110'>				<span class="p">}</span> <span class="k">else</span> <span class="p">{</span></div><div class='line' id='LC111'>					<span class="nx">$</span><span class="p">(</span><span class="nx">options</span><span class="p">.</span><span class="nx">noResults</span><span class="p">).</span><span class="nx">show</span><span class="p">();</span></div><div class='line' id='LC112'>				<span class="p">}</span></div><div class='line' id='LC113'>			<span class="p">}</span></div><div class='line' id='LC114'>			<span class="k">return</span> <span class="k">this</span><span class="p">;</span></div><div class='line' id='LC115'>		<span class="p">};</span></div><div class='line' id='LC116'><br/></div><div class='line' id='LC117'>		<span class="k">this</span><span class="p">.</span><span class="nx">loader</span> <span class="o">=</span> <span class="kd">function</span> <span class="p">(</span><span class="nx">bool</span><span class="p">)</span> <span class="p">{</span></div><div class='line' id='LC118'>			<span class="k">if</span> <span class="p">(</span><span class="k">typeof</span> <span class="nx">options</span><span class="p">.</span><span class="nx">loader</span> <span class="o">===</span> <span class="s2">&quot;string&quot;</span> <span class="o">&amp;&amp;</span> <span class="nx">options</span><span class="p">.</span><span class="nx">loader</span> <span class="o">!==</span> <span class="s2">&quot;&quot;</span><span class="p">)</span> <span class="p">{</span></div><div class='line' id='LC119'>				 <span class="p">(</span><span class="nx">bool</span><span class="p">)</span> <span class="o">?</span> <span class="nx">$</span><span class="p">(</span><span class="nx">options</span><span class="p">.</span><span class="nx">loader</span><span class="p">).</span><span class="nx">show</span><span class="p">()</span> <span class="o">:</span> <span class="nx">$</span><span class="p">(</span><span class="nx">options</span><span class="p">.</span><span class="nx">loader</span><span class="p">).</span><span class="nx">hide</span><span class="p">();</span></div><div class='line' id='LC120'>			<span class="p">}</span></div><div class='line' id='LC121'>			<span class="k">return</span> <span class="k">this</span><span class="p">;</span></div><div class='line' id='LC122'>		<span class="p">};</span></div><div class='line' id='LC123'><br/></div><div class='line' id='LC124'>		<span class="k">this</span><span class="p">.</span><span class="nx">cache</span> <span class="o">=</span> <span class="kd">function</span> <span class="p">()</span> <span class="p">{</span></div><div class='line' id='LC125'><br/></div><div class='line' id='LC126'>			<span class="nx">jq_results</span> <span class="o">=</span> <span class="nx">$</span><span class="p">(</span><span class="nx">target</span><span class="p">);</span></div><div class='line' id='LC127'><br/></div><div class='line' id='LC128'>			<span class="k">if</span> <span class="p">(</span><span class="k">typeof</span> <span class="nx">options</span><span class="p">.</span><span class="nx">noResults</span> <span class="o">===</span> <span class="s2">&quot;string&quot;</span> <span class="o">&amp;&amp;</span> <span class="nx">options</span><span class="p">.</span><span class="nx">noResults</span> <span class="o">!==</span> <span class="s2">&quot;&quot;</span><span class="p">)</span> <span class="p">{</span></div><div class='line' id='LC129'>				<span class="nx">jq_results</span> <span class="o">=</span> <span class="nx">jq_results</span><span class="p">.</span><span class="nx">not</span><span class="p">(</span><span class="nx">options</span><span class="p">.</span><span class="nx">noResults</span><span class="p">);</span></div><div class='line' id='LC130'>			<span class="p">}</span></div><div class='line' id='LC131'><br/></div><div class='line' id='LC132'>			<span class="kd">var</span> <span class="nx">t</span> <span class="o">=</span> <span class="p">(</span><span class="k">typeof</span> <span class="nx">options</span><span class="p">.</span><span class="nx">selector</span> <span class="o">===</span> <span class="s2">&quot;string&quot;</span><span class="p">)</span> <span class="o">?</span> <span class="nx">jq_results</span><span class="p">.</span><span class="nx">find</span><span class="p">(</span><span class="nx">options</span><span class="p">.</span><span class="nx">selector</span><span class="p">)</span> <span class="o">:</span> <span class="nx">$</span><span class="p">(</span><span class="nx">target</span><span class="p">).</span><span class="nx">not</span><span class="p">(</span><span class="nx">options</span><span class="p">.</span><span class="nx">noResults</span><span class="p">);</span></div><div class='line' id='LC133'>			<span class="nx">cache</span> <span class="o">=</span> <span class="nx">t</span><span class="p">.</span><span class="nx">map</span><span class="p">(</span><span class="kd">function</span> <span class="p">()</span> <span class="p">{</span></div><div class='line' id='LC134'>				<span class="k">return</span> <span class="nx">e</span><span class="p">.</span><span class="nx">strip_html</span><span class="p">(</span><span class="k">this</span><span class="p">.</span><span class="nx">innerHTML</span><span class="p">);</span></div><div class='line' id='LC135'>			<span class="p">});</span></div><div class='line' id='LC136'><br/></div><div class='line' id='LC137'>			<span class="nx">rowcache</span> <span class="o">=</span> <span class="nx">jq_results</span><span class="p">.</span><span class="nx">map</span><span class="p">(</span><span class="kd">function</span> <span class="p">()</span> <span class="p">{</span></div><div class='line' id='LC138'>				<span class="k">return</span> <span class="k">this</span><span class="p">;</span></div><div class='line' id='LC139'>			<span class="p">});</span></div><div class='line' id='LC140'><br/></div><div class='line' id='LC141'>			<span class="cm">/*</span></div><div class='line' id='LC142'><span class="cm">			 * Modified fix for sync-ing &quot;val&quot;. </span></div><div class='line' id='LC143'><span class="cm">			 * Original fix https://github.com/michaellwest/quicksearch/commit/4ace4008d079298a01f97f885ba8fa956a9703d1</span></div><div class='line' id='LC144'><span class="cm">			 * */</span></div><div class='line' id='LC145'>			<span class="nx">val</span> <span class="o">=</span> <span class="nx">val</span> <span class="o">||</span> <span class="k">this</span><span class="p">.</span><span class="nx">val</span><span class="p">()</span> <span class="o">||</span> <span class="s2">&quot;&quot;</span><span class="p">;</span></div><div class='line' id='LC146'><br/></div><div class='line' id='LC147'>			<span class="k">return</span> <span class="k">this</span><span class="p">.</span><span class="nx">go</span><span class="p">();</span></div><div class='line' id='LC148'>		<span class="p">};</span></div><div class='line' id='LC149'><br/></div><div class='line' id='LC150'>		<span class="k">this</span><span class="p">.</span><span class="nx">trigger</span> <span class="o">=</span> <span class="kd">function</span> <span class="p">()</span> <span class="p">{</span></div><div class='line' id='LC151'>			<span class="k">this</span><span class="p">.</span><span class="nx">loader</span><span class="p">(</span><span class="kc">true</span><span class="p">);</span></div><div class='line' id='LC152'>			<span class="nx">options</span><span class="p">.</span><span class="nx">onBefore</span><span class="p">();</span></div><div class='line' id='LC153'><br/></div><div class='line' id='LC154'>			<span class="nb">window</span><span class="p">.</span><span class="nx">clearTimeout</span><span class="p">(</span><span class="nx">timeout</span><span class="p">);</span></div><div class='line' id='LC155'>			<span class="nx">timeout</span> <span class="o">=</span> <span class="nb">window</span><span class="p">.</span><span class="nx">setTimeout</span><span class="p">(</span><span class="kd">function</span> <span class="p">()</span> <span class="p">{</span></div><div class='line' id='LC156'>				<span class="nx">e</span><span class="p">.</span><span class="nx">go</span><span class="p">();</span></div><div class='line' id='LC157'>			<span class="p">},</span> <span class="nx">options</span><span class="p">.</span><span class="nx">delay</span><span class="p">);</span></div><div class='line' id='LC158'><br/></div><div class='line' id='LC159'>			<span class="k">return</span> <span class="k">this</span><span class="p">;</span></div><div class='line' id='LC160'>		<span class="p">};</span></div><div class='line' id='LC161'><br/></div><div class='line' id='LC162'>		<span class="k">this</span><span class="p">.</span><span class="nx">cache</span><span class="p">();</span></div><div class='line' id='LC163'>		<span class="k">this</span><span class="p">.</span><span class="nx">results</span><span class="p">(</span><span class="kc">true</span><span class="p">);</span></div><div class='line' id='LC164'>		<span class="k">this</span><span class="p">.</span><span class="nx">stripe</span><span class="p">();</span></div><div class='line' id='LC165'>		<span class="k">this</span><span class="p">.</span><span class="nx">loader</span><span class="p">(</span><span class="kc">false</span><span class="p">);</span></div><div class='line' id='LC166'><br/></div><div class='line' id='LC167'>		<span class="k">return</span> <span class="k">this</span><span class="p">.</span><span class="nx">each</span><span class="p">(</span><span class="kd">function</span> <span class="p">()</span> <span class="p">{</span></div><div class='line' id='LC168'><br/></div><div class='line' id='LC169'>			<span class="cm">/*</span></div><div class='line' id='LC170'><span class="cm">			 * Changed from .bind to .on.</span></div><div class='line' id='LC171'><span class="cm">			 * */</span></div><div class='line' id='LC172'>			<span class="nx">$</span><span class="p">(</span><span class="k">this</span><span class="p">).</span><span class="nx">on</span><span class="p">(</span><span class="nx">options</span><span class="p">.</span><span class="nx">bind</span><span class="p">,</span> <span class="kd">function</span> <span class="p">()</span> <span class="p">{</span></div><div class='line' id='LC173'><br/></div><div class='line' id='LC174'>				<span class="nx">val</span> <span class="o">=</span> <span class="nx">$</span><span class="p">(</span><span class="k">this</span><span class="p">).</span><span class="nx">val</span><span class="p">();</span></div><div class='line' id='LC175'>				<span class="nx">e</span><span class="p">.</span><span class="nx">trigger</span><span class="p">();</span></div><div class='line' id='LC176'>			<span class="p">});</span></div><div class='line' id='LC177'>		<span class="p">});</span></div><div class='line' id='LC178'><br/></div><div class='line' id='LC179'>	<span class="p">};</span></div><div class='line' id='LC180'><br/></div><div class='line' id='LC181'><span class="p">}(</span><span class="nx">jQuery</span><span class="p">,</span> <span class="k">this</span><span class="p">,</span> <span class="nb">document</span><span class="p">));</span></div></pre></div>
          </td>
        </tr>
      </table>
  </div>

          </div>
        </div>

        <a href="#jump-to-line" rel="facebox" data-hotkey="l" class="js-jump-to-line" style="display:none">Jump to Line</a>
        <div id="jump-to-line" style="display:none">
          <h2>Jump to Line</h2>
          <form accept-charset="UTF-8" class="js-jump-to-line-form">
            <input class="textfield js-jump-to-line-field" type="text">
            <div class="full-button">
              <button type="submit" class="button">Go</button>
            </div>
          </form>
        </div>

      </div>
    </div>
</div>

<div id="js-frame-loading-template" class="frame frame-loading large-loading-area" style="display:none;">
  <img class="js-frame-loading-spinner" src="https://a248.e.akamai.net/assets.github.com/images/spinners/octocat-spinner-128.gif" height="64" width="64">
</div>


        </div>
      </div>
      <div class="modal-backdrop"></div>
    </div>

      <div id="footer-push"></div><!-- hack for sticky footer -->
    </div><!-- end of wrapper - hack for sticky footer -->

      <!-- footer -->
      <div id="footer">
  <div class="container clearfix">

      <dl class="footer_nav">
        <dt>GitHub</dt>
        <dd><a href="/about">About us</a></dd>
        <dd><a href="/blog">Blog</a></dd>
        <dd><a href="/contact">Contact &amp; support</a></dd>
        <dd><a href="http://enterprise.github.com/">GitHub Enterprise</a></dd>
        <dd><a href="http://status.github.com/">Site status</a></dd>
      </dl>

      <dl class="footer_nav">
        <dt>Applications</dt>
        <dd><a href="http://mac.github.com/">GitHub for Mac</a></dd>
        <dd><a href="http://windows.github.com/">GitHub for Windows</a></dd>
        <dd><a href="http://eclipse.github.com/">GitHub for Eclipse</a></dd>
        <dd><a href="http://mobile.github.com/">GitHub mobile apps</a></dd>
      </dl>

      <dl class="footer_nav">
        <dt>Services</dt>
        <dd><a href="http://get.gaug.es/">Gauges: Web analytics</a></dd>
        <dd><a href="http://speakerdeck.com">Speaker Deck: Presentations</a></dd>
        <dd><a href="https://gist.github.com">Gist: Code snippets</a></dd>
        <dd><a href="http://jobs.github.com/">Job board</a></dd>
      </dl>

      <dl class="footer_nav">
        <dt>Documentation</dt>
        <dd><a href="http://help.github.com/">GitHub Help</a></dd>
        <dd><a href="http://developer.github.com/">Developer API</a></dd>
        <dd><a href="http://github.github.com/github-flavored-markdown/">GitHub Flavored Markdown</a></dd>
        <dd><a href="http://pages.github.com/">GitHub Pages</a></dd>
      </dl>

      <dl class="footer_nav">
        <dt>More</dt>
        <dd><a href="http://training.github.com/">Training</a></dd>
        <dd><a href="/edu">Students &amp; teachers</a></dd>
        <dd><a href="http://shop.github.com">The Shop</a></dd>
        <dd><a href="/plans">Plans &amp; pricing</a></dd>
        <dd><a href="http://octodex.github.com/">The Octodex</a></dd>
      </dl>

      <hr class="footer-divider">


    <p class="right">&copy; 2013 <span title="0.05319s from fe19.rs.github.com">GitHub</span>, Inc. All rights reserved.</p>
    <a class="left" href="/">
      <span class="mega-octicon octicon-mark-github"></span>
    </a>
    <ul id="legal">
        <li><a href="/site/terms">Terms of Service</a></li>
        <li><a href="/site/privacy">Privacy</a></li>
        <li><a href="/security">Security</a></li>
    </ul>

  </div><!-- /.container -->

</div><!-- /.#footer -->


    <div class="fullscreen-overlay js-fullscreen-overlay" id="fullscreen_overlay">
  <div class="fullscreen-container js-fullscreen-container">
    <div class="textarea-wrap">
      <textarea name="fullscreen-contents" id="fullscreen-contents" class="js-fullscreen-contents" placeholder="" data-suggester="fullscreen_suggester"></textarea>
          <div class="suggester-container">
              <div class="suggester fullscreen-suggester js-navigation-container" id="fullscreen_suggester"
                 data-url="/riklomas/quicksearch/suggestions/commit">
              </div>
          </div>
    </div>
  </div>
  <div class="fullscreen-sidebar">
    <a href="#" class="exit-fullscreen js-exit-fullscreen tooltipped leftwards" title="Exit Zen Mode">
      <span class="mega-octicon octicon-screen-normal"></span>
    </a>
    <a href="#" class="theme-switcher js-theme-switcher tooltipped leftwards"
      title="Switch themes">
      <span class="octicon octicon-color-mode"></span>
    </a>
  </div>
</div>



    <div id="ajax-error-message" class="flash flash-error">
      <span class="octicon octicon-alert"></span>
      Something went wrong with that request. Please try again.
      <a href="#" class="octicon octicon-remove-close ajax-error-dismiss"></a>
    </div>

    
    <span id='server_response_time' data-time='0.05377' data-host='fe19'></span>
    
  </body>
</html>

